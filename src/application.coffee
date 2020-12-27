"use strict"
$ = require "jquery"
require("notifyjs-browser")($)

M = require "./matrix2.coffee"
{convexQuadPoints} = require "./geometry.coffee"
{qform, tfm2qform}  = require "./mathutil.coffee"
{View} = require "./view.coffee"
{World, makeCoord, cellList2Text, sortCellList, parseCellList, parseCellListBig, newCoordHash}= require "./world.coffee"
{ControllerHub}= require "./controller.coffee"
CA = require "./ca.coffee"
{BinaryTotalisticRule, CustomRule} = require "./rule.coffee"
hotkeys = require "hotkeys"
URLSearchParams = require 'url-search-params'
bigInt = require "big-integer"

MAX_SCALE = 100
MIN_SCALE = 5
LOG10 = Math.log 10
CELL_SIZES = [0.1,0.2, 0.3, 0.4, 0.5]
#When population is this big, external worker would be used for calculations.
BIG_POPULATION = 200
WORKER_CACHE_BUST=""+Math.random()

{debounce} = require "throttle-debounce"

parseMatrix = (code) ->
  code = code.trim()
  parts = code.split /\s+/
  if parts.length isnt 4
    throw new Error "Matrix code must have 4 parts"
  return (parseInt(part, 10) for part in parts)

parseNeighborSamples = (code) ->
  vectors = for svector in code.split ';'
    svector = svector.trim()
    parts = (parseInt(part,10) for part in svector.split(' ') when part)
    if parts.length isnt 2
      throw new Error("Neighbor vector must have 2 integer components, separated by spaces")
    parts
  if vectors.length is 0
    throw new Error "Zero sample vectors: neighbors not defined"
  return vectors

stringifyNeighborSamples = (neighs) -> ["#{x} {y}" for [x,y] in neighs].join ";"

class Application
  constructor: ->
    @canvas = $("#canvas").get(0)
    @canvasCtl = $("#canvas-controls").get(0)
    
    @context = @canvas.getContext "2d"
    @contextCtl = @canvasCtl.getContext "2d"
    
    @world = null
    @view = null
    @animations = []
    @needRepaint = true
    @needRepaintCtl = true
    @controller = new ControllerHub this
    @rule = new BinaryTotalisticRule "B3S2 3"
    @stateSelector = new StateSelector this
    @prevState = null
    @criticalPopulation = 1000

    if window.Worker
      @_startWorker()
    else
      @worker = null
    @_workerPending = false    
    @playing = false
    
  _startWorker: ->
    @worker = new Worker "worker.js?buster=#{WORKER_CACHE_BUST}"
    @worker.onmessage = @_renderFinished
    return
    
  setLatticeMatrix: (m) ->
    @world = new World m, [[1,0]]
    if @view is null
      @view = new View @world
    else
      @view.setWorld @world
    @needRepaint = true
    @needRepaintCtl = true
    
  repaintView: ->
    if @view isnt null
      @view.drawGrid @canvas, @context

  repaintControls: ->
    if @view isnt null
      @view.drawControls @canvasCtl, @contextCtl

  startAnimationLoop: ->
    window.requestAnimationFrame @animationLoop
    
  animationLoop: (timestamp)=>
    for animation in @animations
      animation.onFrame this, timestamp

    if @needRepaint
      @repaintView()      
      @needRepaint = false
    if @needRepaintCtl
      @repaintControls()
      @needRepaintCtl = false
    window.requestAnimationFrame @animationLoop
    
  startAnimation: (animation)->
    @animations.push animation
    animation.start()

  stopAnimation: (animation)->
    idx = @animations.indexOf animation
    if idx is -1 then throw new Error("Animation is not present in the animations list")
    @animations.splice idx, 1
    animation.stop()
      
  navigateHome: ->
    @view.setLocation makeCoord(0,0), 0
    @needRepaint = true
    @needRepaintCtl = true
    @updateNavigator()

  updateNavigator: ->
    $("#navi-angle").text( (@view.getTotalAngle() / Math.PI * 180)|0 )

    $("#navi-x").text ""+@view.center.x
    $("#navi-y").text ""+@view.center.y
    
  setHighlightCell: (cell)->
    @view.setHighlightCell cell    
    @showCellCoordinates @view.local2global cell if cell?
    return
    
  showCellCoordinates: (globalCell)->
    $("#status-coord").text "(#{globalCell.x},#{globalCell.y})" if globalCell?
    return
    
  updatePopulation: ->
    pop = $("#info-population")
    pop.text(""+@world.population())
    if @world.population() > @criticalPopulation
      pop.addClass "critical-value"
    else
      pop.removeClass "critical-value"
      
    
  zoomIn: -> @zoomBy Math.pow(10, 0.2)
  zoomOut: -> @zoomBy Math.pow(10, -0.2)
  zoomBy: (k) ->
    @view.setScale Math.min MAX_SCALE, Math.max MIN_SCALE, @view.scale*k
    @needRepaintCtl = true
    @needRepaint = true

  go: ->
    if @playing
      @playing = false
      $("#btn-go").removeClass 'pressed'
      console.log "Stop playing"
    else
      @playing = true
      $("#btn-go").addClass 'pressed'
      console.log "Start playing"
      @step()
    return
    
  step: ->
    return if @_workerPending
    if not @worker or @world.population() < BIG_POPULATION
        @stepLocal()
    else
        @stepWorker()
    return

  _scheduleStep: ->
    setTimeout((()=>@step()), 500)
            
  stepLocal: ->
    @prevState = CA.step @world, @rule
    @updatePopulation()
    @needRepaint = true
    @_scheduleStep() if @playing
    return
    
  stepWorker: ->
    rtype = switch
      when @rule instanceof BinaryTotalisticRule
        "BinaryTotalisticRule"
      when @rule instanceof CustomRule
        "CustomRule"
      else throw new Error("Hmm, bad rule type")
    cells = []
    @world.cells.iter (kv)->
      cells.push [""+kv.k.x, ""+kv.k.y, kv.v]
      return
    @worker.postMessage ['render', [rtype, @rule.toString(), @world.m, @world.c, cells, @view.showConnection]]
    @_workerPending = true
    $("#worker-spinner").show()
    return
    
  _renderFinished: (e)=>
    @_workerPending = false
    [msg, data] = e.data
    if msg is 'error'
        console.log("Error: "+data)
    else if msg is 'OK'
        #applying results
        @prevState = @world.cells
        @world.clear()
        for [x,y,s] in data.cells
          @world.setCell makeCoord(x,y),s
        @updatePopulation()
        @needRepaint = true
        if data.connections?
          @world.connections = newCoordHash()
          cellNeighbors = []
          for [sx, sy, value, neighbors] in data.connections
            connectedCell = new CA.ConnectedCell makeCoord(sx,sy), value, []
            #instead of parsing them immediately - storing for the second pass
            cellNeighbors.push [connectedCell, neighbors] if neighbors.length
            @world.connections.put connectedCell.coord, connectedCell
          #second pass: parse cell to cell connections
          for [connectedCell, neighbors] in cellNeighbors
            for [nx, ny] in neighbors
              coord = makeCoord nx, ny
              connectedCell.neighbors.push @world.connections.get coord
    else
        console.log("Bad answer:"+msg)
    $("#worker-spinner").hide()
    @_scheduleStep() if @playing
    return
  doClear: ->
    if @world.population() > 0
      @prevState = @world.cells
      @world.clear()
      @needRepaint = true
    return
    
  cancelStep: ->
    return if not @_workerPending
    @worker.terminate()
    @_startWorker()
    $("#worker-spinner").hide()
    @_workerPending = false
    @go() if @playing
    return
    

  requestUpdateConnections: debounce 500, false, ->
    #update information about neighbor cells
    if @world.population() < BIG_POPULATION
      @world.connections = CA.calculateConnections @world
      @needRepaint = true
    else
      #TODO: run update connections in worker?
    return
    
  updateCanvasSize: ->
    cont = $ "#canvas-container"
    @canvasCtl.width = @canvas.width = cont.innerWidth() | 0
    @canvasCtl.height = @canvas.height = cont.innerHeight() | 0
    @needRepaint = true
    @needRepaintCtl = true
    return
    
  setShowStateNumbers: (show)->
    @view.showStateNumbers = show
    @needRepaint=true
    return
    
  setShowConnection: (show)->
    @view.showConnection = show
    @needRepaint = true
    @requestUpdateConnections() if show
    return
    
  setShowEmpty: (show) ->
    @view.showEmpty = show
    @needRepaint = true
    return
    
  setShowCenter: (show)->
    @view.showCenter = show
    @needRepaintCtl = true
    return
    
  randomFill: (size, percent)->
    x0 = -((size/2)|0)
    x1 = size + x0
    rand = -> Math.round(Math.random()*size + x0) | 0
      
    numCells = (size**2*percent)|0
    for x in [x0...x1]
      for y in [x0...x1]
        if Math.random() <= percent
          c = makeCoord rand(), rand()
          @world.setCell c, 1+Math.floor(Math.random()*(@rule.states-1))|0
    return
    
  onRandomFill: ->
    try
      size = parseInt $("#fld-random-size").val(), 10
      throw new Error("Bad size") if size <=0 or size > 10000
      percent = parseFloat $("#fld-random-percent option:selected").val()
      throw new Error("Bad percent") if percent < 0 or percent > 100
    
      @world.clear()
      @randomFill size, percent*0.01
      @requestUpdateConnections()
      @updatePopulation()
    catch err
      $.notify err
    @needRepaint=true
    
  onUndo: ->
    if @prevState isnt null
      @world.cells = @prevState
      @prevState = null
      @needRepaint=true
      @updatePopulation()
      
  setRule: (rule) ->
    @rule = rule
    @stateSelector.setNumStates rule.states
    
  setSelection: (cells, updateUI=true) ->
    @controller.paste.selection = cells
    if updateUI
      $("#fld-selection").val if cells is null
        ""
      else
        cellList2Text(cells)
        
  selectionBufferChanged: (event, curText) ->
    try
      curText = $("#fld-selection").val().trim()
      cells = if curText then parseCellList(curText) else null
      @setSelection cells, false #do not update UI
      $("#tool-paste").trigger 'click' if curText
    catch e
      $.notify e
      
      
    
  setNeighborVectors: (vectors)->
    @world.setNeighborVectors vectors
    @view.updateWorld()
    @needRepaintCtl=true
    
  loadPreset: (preset)->
    if preset.matrix?
      #@setLatticeMatrix parseMatrix preset.matrix
      $("#fld-matrix").val(preset.matrix).trigger('change')
      
    if preset.neighbors?
      #@setNeighborVectors parseNeighborSamples preset.neighbors
      $("#fld-sample-neighbor").val(preset.neighbors).trigger('change')

    if preset.pattern?
      cells = parseCellList preset.pattern
      @world.putPattern makeCoord(0,0), cells

    if preset.rule?
      @setRule new BinaryTotalisticRule preset.rule
      $("#fld-rule").val( ""+@rule )
    if preset.customrule
      console.log preset.customrule
      @setRule new CustomRule preset.customrule
      $("#fld-custom-rule-code").val preset.customrule
      
  hideCueMarker: ->
    @view.selectedCell = null
    @needRepaintCtl = true

  saveToUrlParams: ->
    params = new URLSearchParams
    params.set 'matrix', @world.m.join(' ')
    params.set 'neighbors', $("#fld-sample-neighbor").val()
    params.set 'center', "#{@view.center.x},#{@view.center.y}"
    params.set 'angle', ""+@view.getTotalAngle()
    if @rule instanceof BinaryTotalisticRule
      params.set 'rule', ""+@rule
    else if @rule instanceof CustomRule
      params.set 'customrule', ""+@rule

    if @world.population() > 0
      params.set 'cells', cellList2Text @world.getCellList()
    return params
        
  loadFromUrlParams: (params)->
    if params.has 'matrix'
      try
        mtx = params.get 'matrix'
        @setLatticeMatrix parseMatrix mtx
        $("#fld-matrix").val(mtx)
        $.notify "Lattice matrix is set to#{JSON.stringify mtx}", "info"
      catch err
        alert "Bad matrix in url: #{mtx}, #{err}"

    if params.has 'neighbors'
      try
        neighbors = params.get 'neighbors'
        @world.setNeighborVectors parseNeighborSamples neighbors
        @view.updateWorld()
        $("#fld-sample-neighbor").val(neighbors)
        $.notify "Sample neighbors are set to#{neighbors}", "info"
      catch err
        alert "Bad neighbor samples in url: #{neighbors}, #{err}"
        
    if params.has 'center'
      [sx,sy] = params.get('center').split(',')
      center = makeCoord sx, sy
    else
      center = makeCoord 0, 0
    if params.has 'angle'
      angle = parseFloat params.get 'angle'
      throw new Error("bad angle: #{angle}") if angle isnt angle
    else
      angle = 0.0

    @view.setLocation center, angle
      
    if params.has 'cells'
      cells = parseCellListBig params.get 'cells'
      @world.clear()
      @world.putPattern makeCoord(0,0), cells
      @view.selectedCell = null

    if params.has 'rule'
      @setRule new BinaryTotalisticRule params.get 'rule'
      $("#fld-rule").val( ""+@rule )
      $.notify "Rule is set to#{@rule}", "info"
    if params.has 'customrule'
      @setRule new CustomRule params.get 'customrule'
      $("#fld-custom-rule-code").val params.get 'customrule'
      $.notify "Rule is set to custom rule", "info"
    @needRepaint=true
    @needRepaintCtl=true

class StateSelector
  constructor: (@app)->
    @elem = $("#state-selector")
    @nstates = 1
    @buttons = []
    @_updateSelector()
    @activeState = 1
    
  setNumStates: (n)->
    return if n is @nstates
    if n < 2 then throw new Error "Number os states can't be < 2"
      
    @nstates = n
    @_updateSelector()
    if @nstates is 2
      @elem.hide()
    else
      @elem.show()
      
  _updateSelector: ->
    #create buttons for each state
    @elem.empty()
    @buttons = for s in [1...@nstates]
      btn = $("<button>#{s}</button>")
      btn.addClass "state"
      if s is @activeState
        btn.addClass "selected-state"
      btn.css "background-color", @app.view.getStateColor s
      btn.on 'click', do (s)=>(e)=>@_onStateSelected s, e
      @elem.append btn
      btn
      
  _onStateSelected: (s, e)->
    return if s is @activeState
    @buttons[@activeState-1].removeClass 'selected-state'
    @buttons[s-1].addClass 'selected-state'
    @activeState = s
    
defineToggleButton = (jqElement, onToggle)->
  jqElement.on 'click', ->
    jqthis = $ this
    val = not jqthis.hasClass 'pressed'
    jqthis.toggleClass 'pressed'
    onToggle val
  onToggle jqElement.hasClass 'pressed'

class RotateAnimation
  constructor: (@anglePerSec)->
  start: ->
    @lastTimeStamp = null
  stop: ->
  onFrame: (app, timestamp)->    
    if @lastTimeStamp isnt null
      dt = timestamp - @lastTimeStamp
      if dt < 0
        dt = 0
      else if dt > 100
        dt = 100
        
      app.view.incrementAngle @anglePerSec * dt
      app.needRepaint = true
    @lastTimeStamp = timestamp

class ExclusiveButtonGroup
  constructor: (ids)->
    @pressedClass = "pressed"
    @active = null
    buttons = ($("#"+id) for id in ids)
    for btn in buttons
      btn.on 'click', (e)=>@_clicked(e)
      if btn.hasClass @pressedClass
        if @active is null
          @active = btn
        else
          btn.removeClass @pressedClass
    return
     
  _clicked: (e)->
    target = $(e.target)
    return if target.hasClass @pressedClass
    if @active isnt null
      @active.removeClass @pressedClass
    target.addClass @pressedClass
    @active = target
      
class SmartDispatcher extends hotkeys.Dispatcher
  _dispatch: (evt)->
    unless evt.target.tagName.toLowerCase() in ['textarea']
      super(evt)
      
CodeSamples = 
  basic: """//Basic custom rule that re-implements binary rule "B3 S2 3"
//Commented code is the same as default behavior
{
  //states: 2,
  //foldInitial: 0,
  //fold: function(sum, state){return sum+state;},
  next: function(state, sum){
    if (state===0){
      return (sum===3) ? 1 : 0;
    }else if(state===1){
      return (sum===2 || sum===3) ? 1 : 0;
    }
  }
}
""",
  advanced:"""//Advanced code sample, that has several states and counts neighbors of each state separately
//It also shows how custom fields coud be added to the rule
{
  states: 9,
  foldInitial: null,
  fold: function(sum, s){
    if(s===0) return sum;
    if(sum===null){
      sum=new Array(this.states-1);
      for(var i=0; i!=sum.length; ++i) sum[i] = 0;
    }
    sum[s-1] += 1;
    return sum
  },
  //rule is defined by this table, keys are strings, composed of cell state and sorted neighbor states
  map:{
    "1 22":1,
    "2 1344": 5,
    "3 244": 6,
    "4 234": 7,
    "4 234": 7,
    "0 14": 8,
    "1 5588": 1,
    "7 5678":  3,
    "7 567": 0,
    "8 17": 2,
    "0 78": 4,
    "2 13444": 5,
    "1 558888": 1,
  },
  next: function(s, sum){
    var sss=""+s+" ";
    if (sum!=null){
      for(var i=0; i!=sum.length; i++){
        var si = sum[i];
        for(var j=0;j!=si;j++)
          sss = sss + (i+1);
      }
    }
    if (this.map.hasOwnProperty(sss))
      return this.map[sss];
    else
      return 0;
  }
}
"""

$(document).ready ->
  app = new Application $("#canvas").get(0)
  app.updateCanvasSize()
  
  $("#world-clear").click -> app.doClear()
    
  $("#fld-matrix").on 'change', (e)->
    try
      app.setLatticeMatrix parseMatrix $("#fld-matrix").val()
      app.world.setNeighborVectors parseNeighborSamples $("#fld-sample-neighbor").val()
      $.notify "Lattice matrix set to #{JSON.stringify app.world.m}", "info"
      app.view.updateWorld()      
      app.needRepaintCtl=true
    catch err
      $.notify err
    
  $("#fld-matrix").trigger 'change'

  $("#fld-rule").on 'change', (e)->
    try
      app.setRule( new BinaryTotalisticRule $("#fld-rule").val() )
      $("#fld-rule").removeClass("inactive")
      $.notify "Rule is set to #{app.rule}", "info"
    catch err
      $.notify err
      
  $("#fld-sample-neighbor").on 'change', (e)->
    try
      console.log "Sample neighbors changed to "+$(this).val()
      neigh = parseNeighborSamples $(this).val()
      app.setNeighborVectors neigh
      $.notify "Neighbors: #{JSON.stringify neigh}", "info"
    catch err
      $.notify err
    
  $("#fld-rule").trigger 'change'
  $("#fld-sample-neighbor").trigger 'change'

  $("#fld-load-preset").on 'change', (e)->
    try
      app.loadPreset JSON.parse($("#fld-load-preset").val().replace /\'/g, '"' )
    catch err
      $.notify err
    $("#fld-load-preset").val("none")
    

#  $("#btn-run-animation").on "click", (e)->
#    if app.animations.length is 0
#      a = new RotateAnimation 0.0002
#      app.startAnimation a
#    else
#      app.stopAnimation app.animations[0]
      
  $("#btn-go-home").on "click", (e)->app.navigateHome()
  $("#canvas,#canvas-controls").bind 'contextmenu', false
  $("#canvas,#canvas-controls").on "wheel", (e)->
    dy = e.originalEvent.deltaY
    if dy
      #console.log [e.originalEvent.deltaY, ['pixel','line','page'][e.originalEvent.deltaMode]]
      app.zoomBy Math.pow(1.1, if dy > 0 then -1 else 1)
    
  $("#btn-help-shortcuts").on "click", ->  $("#popup-help-shortcuts").toggle()    
  $("#btn-examples").on "click", ->  $("#popup-examples").toggle()
    
  $("#btn-zoom-in").on "click", ->app.zoomIn()
  $("#btn-zoom-out").on "click", ->app.zoomOut()
  $("#btn-step").on "click", ->app.step()
  $("#btn-go").on "click", -> app.go()
  $("#cancel-step").on "click", -> app.cancelStep()
  $("#btn-random-fill").on "click", -> app.onRandomFill()
  $("#btn-set-custom-rule").on 'click', (e)->
    try
      app.setRule new CustomRule $("#fld-custom-rule-code").val()
      $.notify "Rule set to custom"
      $("#popup-custom-rule").hide()
      $("#fld-rule").addClass("inactive")
    catch e
      alert ""+e
  $("#btn-set-custom-rule-cancel").on 'click', -> $("#popup-custom-rule").hide()
      
  if $("#fld-custom-rule-code").val()
    $("#btn-set-custom-rule").trigger 'click'
  $("#btn-show-custom-rule-help").on 'click', -> $('#custom-rule-help').toggle()
    
  $("#fld-selection").on 'change', (e)->
    app.selectionBufferChanged()
    
  $("#fld-selection").on 'input', debounce 500, false, (e)->
    app.selectionBufferChanged()
    
  $("#btn-rot180-selection").on 'click', (e)->
    sel = parseCellList($("#fld-selection").val())
    app.setSelection ([-x,-y,s] for [x,y,s] in sel), true #update UI
    app.needRepaintCtl=true
  $("#btn-show-custom").on 'click', -> $("#popup-custom-rule").toggle()
  $("div.popup").on 'click', (e) ->
    if e.target is this
      $(this).toggle()

  $("#btn-save-url").on 'click', ->
    $("#fld-save-url").val(window.location.href.split('?')[0]+"?"+app.saveToUrlParams())
    $("#popup-save-url").toggle()
  $("#fld-save-url").on 'click', ->
    $(this).select()

  $("#btn-custom-rule-load-sample1").on 'click', ->
    $("#fld-custom-rule-code").val( CodeSamples.basic )
    
  $("#btn-custom-rule-load-sample2").on 'click', ->
    $("#fld-custom-rule-code").val( CodeSamples.advanced )
  
  defineToggleButton $("#tb-view-empty"), (show)->app.setShowEmpty show
  defineToggleButton $("#tb-view-center"), (show)->app.setShowCenter show
  defineToggleButton $("#tb-view-connections"), (show)->app.setShowConnection show
  defineToggleButton $("#tb-view-numbers"), (show)->app.setShowStateNumbers show


  $("#tool-draw").on 'click', -> app.controller.setPrimary(app.controller.draw)
  $("#tool-cue").on 'click', -> app.controller.setPrimary(app.controller.cue)
  $("#tool-cue-hide").on 'click', -> app.hideCueMarker()
  $("#tool-move").on 'click', -> app.controller.setPrimary(app.controller.move)
  $("#tool-squeeze").on 'click', -> app.controller.setPrimary(app.controller.squeeze)
  $("#tool-copy").on 'click', -> app.controller.setPrimary(app.controller.copy)
  $("#tool-paste").on 'click', -> app.controller.setPrimary(app.controller.paste)

  $("#sld-cell-size").on 'input', ->
    app.view.setCellSizeRel CELL_SIZES[@value]
    app.needRepaint = true
    app.needRepaintCtl = true
    
  toolButtons = new ExclusiveButtonGroup ["tool-draw", "tool-cue", "tool-move", "tool-squeeze", "tool-copy", "tool-paste"]

            
  kbDispatcher = new SmartDispatcher
  kbDispatcher.getKeymap()
  kbDispatcher.on "esc", ->$("div.popup").hide()
  
  kbDispatcher.on "n", ->app.step()
  kbDispatcher.on "[", ->app.zoomIn()
  kbDispatcher.on "]", ->app.zoomOut()
  kbDispatcher.on "+", ->app.zoomIn()
  kbDispatcher.on "-", ->app.zoomOut()
  kbDispatcher.on "e", -> app.doClear()
  kbDispatcher.on "h", ->app.navigateHome()
  kbDispatcher.on "a", ->app.onRandomFill()
  kbDispatcher.on "z", ->app.onUndo()


  kbDispatcher.on 'g', ->$("#btn-go").trigger 'click'
  kbDispatcher.on 'd', ->$("#tool-draw").trigger 'click'
  kbDispatcher.on 'm', ->$("#tool-move").trigger 'click'
  kbDispatcher.on 'u', ->$("#tool-cue").trigger 'click'
  kbDispatcher.on 'c', ->$("#tool-copy").trigger 'click'
  kbDispatcher.on 'v', ->$("#tool-paste").trigger 'click'
  kbDispatcher.on 'r', ->$("#tool-squeeze").trigger 'click'

  kbDispatcher.on 'q', -> app.hideCueMarker()

  kbDispatcher.on 'ctrl [', ->
    slider = $("#sld-cell-size").get()
    console.log slider.value
    slider.value = slider.value+1
    console.log slider.value
    slider.trigger "input"
    
  kbDispatcher.on 'ctrl ]', ->
    slider = $("#sld-cell-size")
    console.log slider.val().get()
    slider.val slider.val()-1
    console.log slider.val()
    slider.trigger "input"


  if window.location.search
    app.loadFromUrlParams new URLSearchParams(window.location.search)
    try
      #remove the ugly query string. Not sure if good or bad.
      history.pushState "", document.title, window.location.pathname
    catch
      #ignore

  $("a.reference").on 'click', (e)->
    console.log e.target.href
    url = new URL e.target.href
    app.loadFromUrlParams new URLSearchParams url.search
    $("div.popup").hide()
    return false
    
  $(window).resize -> app.updateCanvasSize()
    

  app.controller.attach $("canvas")

  $("#sld-cell-size").trigger 'input'
  app.updateCanvasSize()
  app.updateNavigator()      
  app.startAnimationLoop()
