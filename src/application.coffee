"use strict"
$ = require "jquery"
require("notifyjs-browser")($)

M = require "./matrix2.coffee"
{convexQuadPoints} = require "./geometry.coffee"
{qform, tfm2qform}  = require "./mathutil.coffee"
{View} = require "./view.coffee"
{World, makeCoord, cellList2Text, sortCellList, parseCellList, parseCellListBig}= require "./world.coffee"
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
    if cell?
      globalCell = @view.local2global cell
      $("#status-coord").text "(#{globalCell.x},#{globalCell.y})"
    return
    
  updatePopulation: ->
    $("#info-population").text(""+@world.population())    
  zoomIn: -> @zoomBy Math.pow(10, 0.2)
  zoomOut: -> @zoomBy Math.pow(10, -0.2)
  zoomBy: (k) ->
    @view.setScale Math.min MAX_SCALE, Math.max MIN_SCALE, @view.scale*k
    @needRepaintCtl = true
    @needRepaint = true

  step: ->
    @prevState = CA.step @world, @rule
    @updatePopulation()
    @needRepaint = true
    
  updateCanvasSize: ->
    cont = $ "#canvas-container"
    @canvasCtl.width = @canvas.width = cont.innerWidth() | 0
    @canvasCtl.height = @canvas.height = cont.innerHeight() | 0
    @needRepaint = true
    @needRepaintCtl = true

  setShowStateNumbers: (show)->
    @view.showStateNumbers = show
    @needRepaint=true
    
  setShowConnection: (show)->
    @view.showConnection = show
    @needRepaint = true
    
  setShowEmpty: (show) ->
    @view.showEmpty = show
    @needRepaint = true
    
  setShowCenter: (show)->
    @view.showCenter = show
    @needRepaintCtl = true
    
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
      @updatePopulation()
    catch err
      $.notify ""+err
    @needRepaint=true
  onUndo: ->
    if @prevState isnt null
      @world.cells = @prevState
      @prevState = null
      @needRepaint=true
      
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
      catch err
        alert "Bad matrix in url: #{mtx}, #{err}"
        return
    if params.has 'neighbors'
      try
        neighbors = params.get 'neighbors'
        @world.setNeighborVectors parseNeighborSamples neighbors
        @view.updateWorld()
        $("#fld-sample-neighbor").val(neighbors)
      catch err
        alert "Bad neighbor samepls in url: #{neighbors}, #{err}"
        return
        
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
      for [x,y,s] in cells
        @world.setCell makeCoord(x,y),s

    if params.has 'rule'
      @setRule new BinaryTotalisticRule params.get 'rule'
      $("#fld-rule").val( ""+@rule )
    if params.has 'customrule'
      @setRule new CustomRule params.get 'customrule'
      $("#fld-custom-rule-code").val params.get 'customrule'
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
  
  $("#world-clear").click ->
    app.world.clear()
    app.needRepaint = true
    
  $("#fld-matrix").on 'change', (e)->
    try
      app.setLatticeMatrix parseMatrix $("#fld-matrix").val()
      app.world.setNeighborVectors parseNeighborSamples $("#fld-sample-neighbor").val()
      $.notify "Lattice matrix set to #{JSON.stringify app.world.m}", "info"
      app.view.updateWorld()      
      app.needRepaintCtl=true
    catch err
      $.notify ""+err
    
  $("#fld-matrix").trigger 'change'

  $("#fld-rule").on 'change', (e)->
    try
      app.setRule( new BinaryTotalisticRule $("#fld-rule").val() )
      $.notify "Rule set to #{app.rule}", "info"
    catch err
      @(this).notify ""+err
      
  $("#fld-sample-neighbor").on 'change', (e)->
    try
      app.world.setNeighborVectors parseNeighborSamples $(this).val()
      $.notify "Sample neeighbors set to #{$(this).val()}", "info"
      app.view.updateWorld()
      app.needRepaintCtl=true
    catch err
      @(this).notify err
      #infobox.text "Faield to set neighbors vectors:"+err
    
  $("#fld-rule").trigger 'change'
  $("#fld-sample-neighbor").trigger 'change'

  $("#btn-run-animation").on "click", (e)->
    if app.animations.length is 0
      a = new RotateAnimation 0.0002
      app.startAnimation a
    else
      app.stopAnimation app.animations[0]
      
  $("#btn-go-home").on "click", (e)->app.navigateHome()
  $("#canvas,#canvas-controls").bind 'contextmenu', false
  $("#btn-zoom-in").on "click", ->app.zoomIn()
  $("#btn-zoom-out").on "click", ->app.zoomOut()
  $("#btn-step").on "click", ->app.step()
  $("#btn-random-fill").on "click", -> app.onRandomFill()
  $("#btn-set-custom-rule").on 'click', (e)->
    try
      app.setRule new CustomRule $("#fld-custom-rule-code").val()
      #infobox.text("Successfully set custom rule")
      $("#popup-custom-rule").hide()
    catch e
      alert ""+e
  $("#btn-set-custom-rule-cancel").on 'click', -> $("#popup-custom-rule").hide()
      
  if $("#fld-custom-rule-code").val()
    $("#btn-set-custom-rule").trigger 'click'
  $("#btn-show-custom-rule-help").on 'click', -> $('#custom-rule-help').toggle()
      
  $("#btn-set-selection").on 'click', (e)->
    app.setSelection parseCellList($("#fld-selection").val()), false #do not update UI
    $("#tool-paste").trigger 'click'
    
  $("#btn-rot180-selection").on 'click', (e)->
    sel = parseCellList($("#fld-selection").val())
    app.setSelection ([-x,-y,s] for [x,y,s] in sel), true #update UI
    app.needRepaintCtl=true
  $("#btn-show-custom").on 'click', -> $("#popup-custom-rule").toggle()
  $("div.popup").on 'click', (e) ->
    $(this).toggle()
  $("div.popup").children().on 'click', -> false

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
  kbDispatcher.on "n", ->app.step()
  kbDispatcher.on "[", ->app.zoomIn()
  kbDispatcher.on "]", ->app.zoomOut()
  kbDispatcher.on "+", ->app.zoomIn()
  kbDispatcher.on "-", ->app.zoomOut()
  kbDispatcher.on "e", ->
    app.world.clear()
    app.needRepaint = true
  kbDispatcher.on "h", ->app.navigateHome()
  kbDispatcher.on "a", ->app.onRandomFill()
  kbDispatcher.on "z", ->app.onUndo()


  kbDispatcher.on 'd', ->$("#tool-draw").trigger 'click'
  kbDispatcher.on 'm', ->$("#tool-move").trigger 'click'
  kbDispatcher.on 'u', ->$("#tool-cue").trigger 'click'
  kbDispatcher.on 'c', ->$("#tool-copy").trigger 'click'
  kbDispatcher.on 'v', ->$("#tool-paste").trigger 'click'
  kbDispatcher.on 'r', ->$("#tool-squeeze").trigger 'click'

  kbDispatcher.on 'shift u', ->
    app.view.selectedCell = null
    app.needRepaintCtl = true

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
  
  $(window).resize -> app.updateCanvasSize()
    

  app.controller.attach $("canvas")

  $("#sld-cell-size").trigger 'input'
  app.updateCanvasSize()
  app.updateNavigator()      
  app.startAnimationLoop()
