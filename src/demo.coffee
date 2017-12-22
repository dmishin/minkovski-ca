"use strict"
$ = require "jquery"
M = require "./matrix2.coffee"
{convexQuadPoints} = require "./geometry.coffee"
{qform, tfm2qform}  = require "./mathutil.coffee"
{View} = require "./view.coffee"
{World, makeCoord}= require "./world.coffee"
{ControllerHub}= require "./controller.coffee"
CA = require "./ca.coffee"
{BinaryTotalisticRule} = require "./rule.coffee"
hotkeys = require "hotkeys"

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
      lsqueeze = @view.getTotalAngle()
      
      $("#navi-squeeze").text( if lsqueeze >= 0
        "#{Math.exp lsqueeze}"
      else
        "1/#{Math.exp -lsqueeze}")
    $("#navi-x").text ""+@view.center.x
    $("#navi-y").text ""+@view.center.y
  updatePopulation: ->
    $("#info-population").text(""+@world.population())    
  zoomIn: -> @zoomBy Math.pow(10, 0.2)
  zoomOut: -> @zoomBy Math.pow(10, -0.2)
  zoomBy: (k) ->
    @view.scale *= k
    @needRepaintCtl = true
    @needRepaint = true

  step: ->
    CA.step @world, @rule
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
    
muls = (mtxs...) ->
  m = mtxs[0]
  for mi in mtxs[1..]
    m = M.mul m, mi
  return m

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
      app.rule = new BinaryTotalisticRule $("#fld-rule").val()
      infobox.text "Rule set to #{app.rule}"
    catch err
      console.log ""+err
      infobox.text "Error setting rule:"+err
      
  $("#fld-sample-neighbor").on 'change', (e)->
    try
      app.world.setNeighborVectors parseNeighborSamples $(this).val()
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
  
  $("#cb-show-connections").on 'change', (e)->app.setShowConnection $(this).prop 'checked'
  $("#cb-show-empty").on 'change', (e)->app.setShowEmpty $(this).prop 'checked'

  kbDispatcher = new hotkeys.Dispatcher
  kbDispatcher.getKeymap()
  kbDispatcher.on "n", ->app.step()
  kbDispatcher.on "[", ->app.zoomIn()
  kbDispatcher.on "]", ->app.zoomOut()
  kbDispatcher.on "c", ->
    app.world.clear()
    app.needRepaint = true
  kbDispatcher.on "h", ->app.navigateHome()
  
  $(window).resize -> app.updateCanvasSize()
    

  app.controller.attach $("canvas")

  app.updateCanvasSize()
  app.updateNavigator()      
  app.startAnimationLoop()
