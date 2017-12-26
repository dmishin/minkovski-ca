M = require "./matrix2.coffee"

getMousePos = (canvas, evt) ->
  rect = canvas.getBoundingClientRect()
  [evt.clientX - rect.left, evt.clientY - rect.top]

class BaseController
  constructor: (@app) ->
  mousedown: (e)->
  mousemove: (e)->
  mouseup: (e)->

  mouse2local: (e)-> @app.view.screen2localInteger @app.canvas, getMousePos @app.canvas, e
  requestRepaint: ->
    @app.needRepaint = true
  requestRepaintControls: ->
    @app.needRepaintCtl = true

class HighlightController extends BaseController
  constructor: (app)->
    super(app)
    @lastHighlight = [0,0]
    
  mousemove: (e)->
    hlCell = @mouse2local e
    if not M.equal hlCell, @lastHighlight
      @lastHighlight = hlCell
      @app.view.setHighlightCell hlCell
      @requestRepaintControls()  
  
class ToggleCellController extends BaseController
  constructor: (app)->
    super(app)
    @value = 1
    @writingValue = 1
    @prevCell = null
    @drawing = false
    
  mousedown: (e)->
    @drawing = true
    @value = @app.stateSelector.activeState
    localCell = @mouse2local e
    globalCell = @app.view.local2global localCell
    if @app.world.getCell(globalCell) is 0
      @writingValue = @value
    else
      @writingValue = 0
      
    @prevCell = localCell
    
    @app.world.setCell globalCell, @writingValue
    @requestRepaint()
    @app.updatePopulation()
    
  mousemove: (e)->
    curCell = @mouse2local e
    return if (@prevCell isnt null) and (M.equal curCell, @prevCell)
    @prevCell = curCell
    
    if @drawing
      globalCell = @app.view.local2global curCell
      oldValue = @app.world.getCell globalCell
      @app.world.setCell globalCell, @writingValue
      
      if oldValue isnt @writingValue
        @requestRepaint()
        @app.updatePopulation()
    else
      #highlighting
      @app.view.setHighlightCell curCell
      @requestRepaintControls()  
        
  mouseup: (e)->
    @drawing = false
      
class SelectCellController extends BaseController
  mousedown: (e)->
    localCell = @mouse2local e
    @app.view.selectedCell =
      if @app.view.selectedCell is null or not M.equal(@app.view.selectedCell, localCell)
        localCell
      else
        null
    @requestRepaintControls()

class CopyController extends BaseController
  constructor: (app)->
    super(app)
    @dragging = false
    @p0 = null
    @p1 = null
    
  mousedown: (e)->
    @dragging = true
    @p0 = getMousePos @app.canvas, e
    @p1 = @p0
    @_updateSelection()
    
  _updateSelection: ->
    @app.view.setSelectionBox( @p0, @p1 )
    @requestRepaintControls()
    
  mousemove: (e)->
    if @dragging
      @p1 = getMousePos @app.canvas, e
      @_updateSelection()

  mouseup: (e)->
    cells = @app.view.copySelection(@app.canvas)
    @app.view.clearSelectionBox()
    @requestRepaintControls()

    #console.log cells
    @app.controller.paste.selection = cells
    
class PasteController extends BaseController
  constructor: (app)->
    super(app)
    @selection = null
    @lastHighlight = [0,0]
    
  mousemove: (e)->
    return if @selection is null
    
    hlCell = @mouse2local e
    if not M.equal hlCell, @lastHighlight
      @lastHighlight = hlCell
      @app.view.setPasteLocation hlCell, @selection
      @requestRepaintControls()
      
  mousedown: (e)->
    pass
  

class SkewController extends BaseController
  constructor: (app)->
    super(app)
    @dragging = false
    @orig = null
    @skewCenter = null
    @speed = 0.01
    
  mousedown: (e)->
    @dragging = true
    @orig = getMousePos(@app.canvas, e)
    @skewCenter = @app.view.screen2localInteger @app.canvas, @orig
    
  mouseup: (e)->
    @dragging = false
    @app.updateNavigator()
    
  mousemove: (e)->
    if @dragging
      pos = getMousePos(@app.canvas, e)

      #before skewing, translate center to the origin
      #this idea did not work, must do something better
      #app.view.translateCenterLocal @skewCenter
      @app.view.incrementAngle((pos[0]-@orig[0])*@speed)
      #then translate it back
      #app.view.translateCenterLocal M.smul -1, @skewCenter
      @orig = pos
      @requestRepaint()
      @requestRepaintControls()
    
      
class MoveController extends BaseController
  constructor: (app)->
    super(app)
    @dragging = false
    @originLocal = null
  mousedown: (e)->
    @dragging = true
    @originLocal = @mouse2local e
    
  mousemove: (e)->
    return unless @dragging
    [x,y] = @mouse2local e
    [ox,oy] = @originLocal
    dx = ox-x
    dy = oy-y
    if dx isnt 0 or dy isnt 0
      @app.view.translateCenterLocal [dx, dy]
      @requestRepaint()
      @requestRepaintControls()
      @originLocal = [x,y]
      
  mouseup: (e)->
    @dragging = false
    @originLocal = null
    @app.updateNavigator()

exports.ControllerHub = class ControllerHub
  constructor: (@app)->

    @paste = new PasteController(@app)
    
    @primary = new ToggleCellController(@app)
    @secondary = new SelectCellController(@app)
    #@secondary = new CopyController(@app)
    @shiftPrimary = new SkewController(@app)
    @shiftSecondary = new MoveController(@app)
    @idle=@paste
    
    @active = @primary

  mousemove: (e)=>
    if @active isnt null
      @active.mousemove e
    else
      @idle.mousemove e
    e.preventDefault()
  mousedown: (e)=>
    if e.button is 0
      if e.shiftKey
        @active = @shiftPrimary
      else if e.ctrlKey
        @active = @shiftSecondary
      else
        @active = @primary
    else if e.button is 2
      if e.shiftKey
        @active = @shiftSecondary
      else
        @active = @secondary
      
    if @active isnt null
      e.target.setCapture?()
      
      @active.mousedown e
      e.preventDefault()
      
  mouseup: (e)=>
    if @active isnt null
      try
        @active.mouseup e
      catch err
        console.log err
      e.preventDefault()
      @active = @primary

  attach: (canvas)->
    canvas.mousedown(@mousedown).mouseup(@mouseup).mousemove(@mousemove)

