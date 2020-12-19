M = require "./matrix2.coffee"
{calcStraightLine} = require "./linedrawing.coffee"

getMousePos = (canvas, evt) ->
  rect = canvas.getBoundingClientRect()
  [evt.clientX - rect.left, evt.clientY - rect.top]

class BaseController
  constructor: (@app) ->
  mousedown: (e)->
  mousemove: (e)->
  mouseup: (e)->
  cancel: ->

  alternative: null

  mouse2local: (e)-> @app.view.screen2localInteger @app.canvas, getMousePos @app.canvas, e
  requestRepaint: ->
    @app.needRepaint = true
  requestRepaintControls: ->
    @app.needRepaintCtl = true

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
    oldPrevCell = @prevCell
    @prevCell = curCell
    
    if @drawing
      for curCell1 in (if oldPrevCell? then calcStraightLine(curCell, oldPrevCell) else [curCell])
        curCell = curCell1
        globalCell = @app.view.local2global curCell
        
        oldValue = @app.world.getCell globalCell
        @app.world.setCell globalCell, @writingValue
        if oldValue isnt @writingValue
          @requestRepaint()
          @app.updatePopulation()
    else
      #highlighting
      
      @app.setHighlightCell curCell
      @requestRepaintControls()  
        
  mouseup: (e)->
    @cancel()

  cancel: ->
    @requestRepaintControls()  
    @app.view.setHighlightCell null
    @drawing = false
      
class SelectCellController extends BaseController
  mousedown: (e)->
    localCell = @mouse2local e
    @app.view.toggleSelectedCell localCell    
    @app.showCellCoordinates @app.view.getSelectedCellGlobal()
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
    @dragging = false
    #console.log cells
    @app.setSelection cells
  cancel: (e)->
    @requestRepaintControls()  
    @dragging = false
    @app.view.clearSelectionBox()
          
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
    [xc, yc] = @mouse2local e
    for [x,y,s] in @selection
      @app.world.setCell @app.view.local2global([xc+x,yc+y]), s
    @requestRepaint()
    
  cancel: ->
    @app.view.setPasteLocation null
    @requestRepaintControls()
    
class SqueezeController extends BaseController
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
      @app.view.highlightedCell = null
      
      #before skewing, translate center to the origin
      #this idea did not work, must do something better
      #app.view.translateCenterLocal @skewCenter
      @app.view.incrementAngle((pos[0]-@orig[0])*@speed)
      #then translate it back
      #app.view.translateCenterLocal M.smul -1, @skewCenter
      @orig = pos
      @requestRepaint()
      @requestRepaintControls()
  cancel: -> @dragging=false
      
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
  cancel: -> @dragging=false

exports.ControllerHub = class ControllerHub
  constructor: (@app)->

    @paste = new PasteController(@app)
    @draw = new ToggleCellController(@app)
    @cue = new SelectCellController(@app)
    @move = new MoveController(@app)
    @squeeze = new SqueezeController(@app)
    @copy = new CopyController(@app)
        
    @primary = @draw
    @shiftPrimary = @squeeze
    @shiftSecondary = @move

    declareAlternativePair = (c1,c2)->
      c1.alternative = c2
      c2.alternative = c1

    declareAlternativePair @draw, @cue
    declareAlternativePair @move, @squeeze
    declareAlternativePair @paste, @copy
    
    @active = @primary

  setPrimary: (subcontroller)->
    return if @primary is subcontroller

    @active.cancel()
    @primary = subcontroller
    @active = subcontroller
    
  mousemove: (e)=>
    if @active isnt null
      @active.mousemove e
    e.preventDefault()
    
  mousedown: (e)=>
    @active = if e.button is 0
      if e.shiftKey
        @shiftPrimary
      else if e.ctrlKey
        @shiftSecondary
      else
        @primary
    else if e.button is 2
      if e.shiftKey
        @shiftSecondary
      else
        @primary.alternative
      
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

