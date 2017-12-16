"use strict"

$ = require "jquery"
M = require "./matrix2.coffee"
{convexQuadPoints} = require "./geometry.coffee"
{qform, tfm2qform}  = require "./mathutil.coffee"
{View} = require "./view.coffee"
{World, makeCoord}= require "./world.coffee"
{ControllerHub}= require "./controller.coffee"
CA = require "./ca.coffee"

canvas = $("#canvas").get(0)
infobox = $ "#info"

ctx = canvas.getContext "2d"


infobox.text "Loaded"


parseMatrix = (code) ->
  code = code.trim()
  parts = code.split /\s+/
  if parts.length isnt 4
    throw new Error "Matrix code must have 4 parts"
  return (parseInt(part, 10) for part in parts)


class Application
  constructor: (@canvas, @context)->
    @world = null
    @view = null
    @animation = null
    @needRepaint = true
    @lastFrameTimestamp = null
    @controller = new ControllerHub this
  
  setLatticeMatrix: (m) ->
    console.log "Setting matrix #{JSON.stringify m}"  
    app.world = new World m, [1,0]
    app.view = new View app.world
    @needRepaint = true
    
  repaintView: ->
    if @view isnt null
      @view.drawGrid canvas, ctx

  startAnimationLoop: ->
    window.requestAnimationFrame @animationLoop
    
  animationLoop: (timestamp)=>
    if @lastFrameTimestamp is null
      @lastFrameTimestamp = timestamp
    if @needRepaint
      @repaintView()      
      @needRepaint = false
    window.requestAnimationFrame @animationLoop

  navigateHome: ->
    @view.setLocation makeCoord(0,0), 0
    @needRepaint = true  
    @updateNavigator()

  updateNavigator: ->
    if @world.isEuclidean
      $("#navi-skew").text("--")
    else
      #its a logarithm of a skew
      lskew = @view.getTotalAngle()
      
      $("#navi-skew").text( if lskew >= 0
        "#{Math.exp lskew}"
      else
        "1/#{Math.exp -lskew}")
    $("#navi-x").text ""+@view.center.x
    $("#navi-y").text ""+@view.center.y
    
    
muls = (mtxs...) ->
  m = mtxs[0]
  for mi in mtxs[1..]
    m = M.mul m, mi
  return m


class Animation
  constructor: (@anglePerSec)->
    @angle = 0.0
    @playing = false
    
  start: ->
    return if @playing
    @playing = true
    @play()
    
  stop: ->
    @playing = false
    
  play: ->
    
    lastTimeStamp = null
    frame = (timestamp)=>
      app.view.drawGrid canvas, ctx
      app.view.setAngle @angle
      if lastTimeStamp isnt null
          dt = timestamp - lastTimeStamp
          if dt < 0
            dt = 0
          @angle += @anglePerSec * dt
          invariantAngle = app.world.angle
          if @angle > invariantAngle
            @angle -= invariantAngle
      lastTimeStamp = timestamp
      if @playing
        window.requestAnimationFrame frame

    window.requestAnimationFrame frame

app = new Application canvas, ctx
        
$("#world-clear").click ->
  app.world.clear()
  app.needRepaint = true
  
$("#replace-neighbors").click (e)->
  nn = CA.newNeighbors app.world
  console.log "New world has #{nn.size()} cells"
  nn.iter (kv) ->
    app.world.cells.put kv.k, 1
  app.needRepaint = true
$("#fld-matrix").on 'change', (e)->
  try
    app.setLatticeMatrix parseMatrix $("#fld-matrix").val()
    infobox.text "Lattice matrix set"
  catch err
    console.log ""+err
    infobox.text ""+err
  
$("#fld-matrix").trigger 'change'
$("#btn-run-animation").on "click", (e)->
  if app.animation is null
    app.animation = new Animation 0.0002
    app.animation.start()
    console.log "Animation start"
  else
    app.animation.stop()
    app.animation = null
    console.log "Animation stop"

$("#btn-go-home").on "click", (e)->app.navigateHome()

$("#canvas").bind 'contextmenu', false




app.controller.attach $("canvas")



app.updateNavigator()      
app.startAnimationLoop()
