"use strict"
$ = require "jquery"
M = require "./matrix2.coffee"
{convexQuadPoints} = require "./geometry.coffee"
{qform, tfm2qform}  = require "./mathutil.coffee"
{View} = require "./view.coffee"
{World, makeCoord}= require "./world.coffee"
{ControllerHub}= require "./controller.coffee"
CA = require "./ca.coffee"
{BinaryTotalisticRule, CustomRule} = require "./rule.coffee"
hotkeys = require "hotkeys"

MAX_SCALE = 100
MIN_SCALE = 5
LOG10 = Math.log 10

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
    console.log "Setting matrix #{JSON.stringify m}"  
    @world = new World m, [[1,0]]
    @view = new View @world
    @needRepaint = true
    
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
    if @world.isEuclidean
      $("#navi-squeeze").text("--")
    else
      #its a logarithm of a squeeze
      log10squeeze = Math.round(@view.getTotalAngle() / LOG10) | 0

      if @lastLog10Squeeze isnt log10squeeze
        $("#navi-squeeze").html "10<sup>#{log10squeeze}</sup>"
        @lastLog10Squeeze = log10squeeze

    $("#navi-x").text ""+@view.center.x
    $("#navi-y").text ""+@view.center.y
  updatePopulation: ->
    $("#info-population").text(""+@world.population())    
  zoomIn: -> @zoomBy Math.pow(10, 0.2)
  zoomOut: -> @zoomBy Math.pow(10, -0.2)
  zoomBy: (k) ->
    @view.scale = Math.min MAX_SCALE, Math.max MIN_SCALE, @view.scale*k
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
      console.log [size, percent*0.01]
      @randomFill size, percent*0.01
      @updatePopulation()
    catch err
      console.log err
    @needRepaint=true
  onUndo: ->
    if @prevState isnt null
      @world.cells = @prevState
      @prevState = null
      @needRepaint=true
      
  setRule: (rule) ->
    @rule = rule
    @stateSelector.setNumStates rule.states


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
    console.log "selected state #{s}"
    
muls = (mtxs...) ->
  m = mtxs[0]
  for mi in mtxs[1..]
    m = M.mul m, mi
  return m

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

class SmartDispatcher extends hotkeys.Dispatcher
  _dispatch: (evt)->
    unless evt.target.tagName.toLowerCase() in ['textarea']
      super._dispatch(evt)

$(document).ready ->
  infobox = $ "#info"
  infobox.text "Loaded"
  app = new Application $("#canvas").get(0)

  app.updateCanvasSize()
  
  $("#world-clear").click ->
    app.world.clear()
    app.needRepaint = true
    
  $("#fld-matrix").on 'change', (e)->
    try
      app.setLatticeMatrix parseMatrix $("#fld-matrix").val()
      infobox.text "Lattice matrix set"
    catch err
      console.log ""+err
      infobox.text ""+err
    
  $("#fld-matrix").trigger 'change'

  $("#fld-rule").on 'change', (e)->
    try
      app.setRule( new BinaryTotalisticRule $("#fld-rule").val() )
      infobox.text "Rule set to #{app.rule}"
    catch err
      console.log ""+err
      infobox.text "Error setting rule:"+err
      
  $("#fld-sample-neighbor").on 'change', (e)->
    try
      app.world.setNeighborVectors parseNeighborSamples $(this).val()
      app.needRepaintCtl=true
    catch err
      console.log err
      infobox.text "Faield to set neighbors vectors:"+err
    
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
      infobox.text("Successfully set custom rule")
    catch e
      infobox.text("Error settign rule: #{e}")

  defineToggleButton $("#tb-view-empty"), (show)->app.setShowEmpty show
  defineToggleButton $("#tb-view-center"), (show)->app.setShowCenter show
  defineToggleButton $("#tb-view-connections"), (show)->app.setShowConnection show
            
  kbDispatcher = new SmartDispatcher
  kbDispatcher.getKeymap()
  kbDispatcher.on "n", ->app.step()
  kbDispatcher.on "[", ->app.zoomIn()
  kbDispatcher.on "]", ->app.zoomOut()
  kbDispatcher.on "c", ->
    app.world.clear()
    app.needRepaint = true
  kbDispatcher.on "h", ->app.navigateHome()
  kbDispatcher.on "r", ->app.onRandomFill()
  kbDispatcher.on "z", ->app.onUndo()
  
  $(window).resize -> app.updateCanvasSize()
    

  app.controller.attach $("canvas")

  app.updateCanvasSize()
  app.updateNavigator()      
  app.startAnimationLoop()
