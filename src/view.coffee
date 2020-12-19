"use strict";

bigInt = require "big-integer"
M = require "./matrix2.coffee"
B = require "./bigmatrix.coffee"

{convexQuadPoints} = require "./geometry.coffee"
{qform}  = require "./mathutil.coffee"
{Coord, makeCoord} = require "./world.coffee"
{drawAllBranches} = require "./ode_curve_drawing.coffee"
#CA = require "./ca.coffee"


# meaning of the coordinates:
#
#  Global: integer coordinates, large ints.
#
#  local: integer. local = bigViewMatrix * (global - center)
#
#      where
#         bigViewMatrix : det1 big int matrix, power of the lattice invariant matrix.
#
#  graphical: float coordinate on the screen, relative to the view center.
#        graphical = viewMatrix * latticeMatrix * local
#
#      where
#          viewMatrix : flat matrix, either pure rotation or pure pseudo-rotation
#  

exports.View = class View
  constructor: (@world) ->
    @viewMatrix = M.eye()
    @viewMatrixBig = B.eye()
    @center = makeCoord 0, 0
    @integerRotationsCount = 0
    @angle = 0.0
    @scale = 20
    @cellSize = 8
    @cellSizeRel = 0.5
    
    @palette = ["#000000", "#fe8f0f", "#f7325e", "#7dc410", "#0264ed"]
    @equidistantColor = "#808080"
    @emptyCellColor = "#c0c0c0"
    @connectionLineColor = "rgba(127,127,127,0.5)"
    
    @selectedCell = [0,0] #null or [ix, iy] pair. Small integers, relative to the view center.
    @highlightedCell = null
    @showConnection = true
    @showEmpty = false

    @styleConnectionLine = "#efe"
    @selectionBox = null
    
    @pasteLocation = null
    @pasteSelection = null

    @showCenter = true
    @guideColor = "rgba(50,50,200,.5)"
    @showStateNumbers = true
    @stateFont = "15px Arial"
    @selectedCellColor = "green"
    @selectedNeighborsColor = "brown"

    @displayedNeighbors = [[3,3]]
    @updateWorld()

  setWorld: (w) ->
    @world=w
    @viewMatrix = M.eye()
    @viewMatrixBig = B.eye()
    @center = makeCoord 0, 0
    @integerRotationsCount = 0
    @angle = 0.0
    @updateWorld()

  getSelectedCellGlobal: ->
    if @selectedCell
      @local2global @selectedCell
    else
      null
    
  toggleSelectedCell: (localCell)->
    @selectedCell = 
      if @selectedCell is null or not M.equal(@selectedCell, localCell)
        localCell
      else
        null
    return
    

  drawCellShape: (context, x, y, s)->
    context.beginPath()
    context.arc(x, y, @cellSize*s, 0, Math.PI*2, true)
    context.closePath()


  drawCellShapeStar: (ctx, x, y, s)->
    d0 = @cellSize*s
    d = d0*-0.2
    d2 = d0*4.0
    
    #ctx.beginPath()
    ctx.moveTo(x-d2, y-d2)
    ctx.bezierCurveTo(x-d, y-d, x+d,y-d, x+d2,y-d2)
    ctx.bezierCurveTo(x+d, y-d, x+d,y+d, x+d2,y+d2)
    ctx.bezierCurveTo(x+d, y+d, x-d,y+d, x-d2,y+d2)
    ctx.bezierCurveTo(x-d, y+d, x-d,y-d, x-d2,y-d2)
    ctx.closePath()
   
        
  setSelectionBox: (p1, p2) -> @selectionBox = [p1,p2]
  clearSelectionBox: -> @selectionBox = null
  copySelection: (canvas)->
    if @selectionBox is null then return null
    dx = canvas.width/2
    dy = canvas.height/2
    [[x1,y1], [x2,y2]] = @selectionBox
    x1 -= dx
    y1 -= dy
    x2 -= dx
    y2 -= dy
    T = @_combinedViewMatrix()
    invT = M.inv T
    #quad in the screen coordinates
    quad = [ [x1, y1], [x2, y1], [x2, y2], [x1, y2]]

    #transform it to the integer lattice
    iquad  = (M.mulv(invT, vi) for vi in quad)
    
    invViewBig = B.adjoint @viewMatrixBig

    points = []
    sumx = 0
    sumy = 0
    convexQuadPoints iquad, (ix, iy) =>
      # [ix,iy] is in the "local" coordinates.
      cellCoord = @local2global [ix, iy]
      cellState = @world.getCell(cellCoord)    
      if cellState isnt 0
        points.push [ix, iy, cellState]
        sumx += ix
        sumy += iy
    if points.length isnt 0
      xc = (sumx/points.length)|0
      yc = (sumy/points.length)|0
      points = ([x-xc,y-yc,s] for [x,y,s] in points)
    return points
    
  setHighlightCell: (v)-> @highlightedCell = v
  incrementAngle: (da) ->
    @angle += da
    #console.log @world.angle
    direction = 0
    if @angle < -0.51*@world.angle
      @angle += @world.angle
      direction = -1
    else if @angle > 0.51*@world.angle
      @angle -= @world.angle
      direction = 1
      
    if direction isnt 0
      @integerRotationsCount += direction
      @_premultiplyViewMatrixBy if direction is 1 then M.adjoint(@world.m) else @world.m
      
    @setAngle @angle

  #moltiply view matrix by a given small matrix (it could only be a power of world.m)
  _premultiplyViewMatrixBy: (p)->
    @viewMatrixBig = B.mul B.tobig(p), @viewMatrixBig
    
    #update other parameters that depend on view matrix
    if @selectedCell isnt null
      @selectedCell = M.mulv p, @selectedCell
      if Math.abs(@selectedCell[0]) + Math.abs(@selectedCell[1]) > 1000000
        console.log "Selection lost because of too big skew"
        @selectedCell = null
        
  getTotalAngle: -> @angle + @integerRotationsCount*@world.angle

  setLocation: (newCenter, fullAngle) ->
    @center = newCenter
    nRotations = fullAngle / @world.angle
    fullRoations = Math.round(nRotations)|0
    @integerRotationsCount = fullRoations
    @setAngle fullAngle - fullRoations*@world.angle
    @viewMatrixBig = if fullRoations <= 0
      B.pow B.tobig(@world.m), -fullRoations
    else
      B.pow B.adjoint(B.tobig(@world.m)), fullRoations
    
    
  
  setAngle: (v)->
    @angle = v
    @viewMatrix = if @world.isEuclidean
        M.rot -v
      else
        #k = Math.exp v
        #M.diag k, 1.0/k
        M.hrot -v
        
  #translate center in "local" integer coordinates. dv must be a small integer vector
  translateCenterLocal: (dv)->
    dvGlobal = B.mulv B.adjoint(@viewMatrixBig), dv
    @center = @center.translate dvGlobal
    if @selectedCell isnt null
      @selectedCell = M.vcombine @selectedCell, -1, dv
    
  #cpnvert screen coordinates to integer translation relative to view center.
  screen2localInteger: (canvas, sxy) ->
    w = canvas.width
    h = canvas.height
    T = M.smul @scale, M.mul @viewMatrix, M.inv(@world.latticeMatrix)
    invT = M.inv T
    [sx,sy] = sxy
    [ix,iy] = M.mulv invT, [sx-w*0.5,sy-h*0.5]
    [Math.round(ix) | 0, Math.round(iy) | 0]

  #convert local integer coordinates to global Coord instance
  local2global: (xy) ->
    @center.translate B.mulv B.adjoint(@viewMatrixBig), xy
    
  updateWorld: ->
    @_calculateDisplayedNeighbors(20)
    
  #find some neighbors to display with guide
  _calculateDisplayedNeighbors: (range)->
    [a,b,_,c] = @world.a
    neighs = []
    addxy = (x,yc, c)->
      return if yc%c isnt 0
      y = (yc/c) |0
      return if Math.abs(y) > range
      neighs.push [x,y]
      
    for x in [-range...range] by 1
      for d in @world.c
        #y = (sqrt((b^2-a*c)*x^2+c*d)-b*x)/c
        q = (b*b-a*c)*x*x+c*d
        continue if q < 0
        qroot = Math.sqrt(q)|0
        continue if qroot*qroot isnt q
        
        addxy x, (qroot-b*x), c
        if qroot isnt 0
          addxy x, (-qroot-b*x), c          
     @displayedNeighbors = neighs
        
  drawEquidistant: (canvas, context, x0, y0, xy)->
    w = canvas.width
    h = canvas.height
    context.save()
    context.translate x0, y0

    #A, x0, y0, x1, y1, step
    context.beginPath()

    #calculate equiistant matrix
    # equation in integer (global) coordinates:
    # X'AX = c
    #
    # Let Y is screen coords, then equation is
    #
    # Y = VX     where V is lattice matrix
    # X = V^-1Y
    #
    # Y' V^-1' A V^-1 Y = c

    #original
    #iV = M.inv @_combinedViewMatrix()
    #simplified
    iV = @world.latticeMatrix
     
    mtx = M.smul 1.0/(xy*@scale*@scale), M.mul M.transpose(iV), M.mul @world.a, iV
    
    for segment in drawAllBranches(mtx, -x0, -y0, w-x0, h-y0, 0.1)
      for [x,y],i in segment
        if i is 0
          context.moveTo x, y
        else
          context.lineTo x, y
    context.strokeStyle = @equidistantColor
    context.setLineDash [5, 5]
    context.stroke()
    
    #find intersection points
    context.restore()

  drawControls: (canvas, context)->
    width = canvas.width
    height = canvas.height

    dx = width * 0.5
    dy = height * 0.5
    T = @_combinedViewMatrix()
    #invT = M.inv T

    context.clearRect(0, 0, canvas.width, canvas.height)
    if @showCenter
      context.strokeStyle = @guideColor
      sz = Math.min(width, height)*0.1
      
      context.beginPath()
      context.moveTo dx-sz, dy-sz
      context.lineTo dx+sz, dy+sz
      context.moveTo dx-sz, dy+sz
      context.lineTo dx+sz, dy-sz
      context.stroke()
      
    if @selectedCell isnt null
      [selx, sely] = M.mulv T, @selectedCell
      for ci in @world.c
        @drawEquidistant canvas, context, selx+dx, sely+dy, ci

      @drawCellShape context, selx+dx, sely+dy, 1.5
      context.strokeStyle = @selectedCellColor
      context.stroke()

      #draw neighbors of the selectedCell
      context.strokeStyle = @selectedNeighborsColor
      for nxy in @displayedNeighbors
        [ndx,ndy] = M.mulv T, nxy
        @drawCellShape context, selx+dx+ndx, sely+dy+ndy, 1
        context.stroke()
      
    if @highlightedCell isnt null
      [hx, hy] = M.mulv T, @highlightedCell
      @drawCellShape context, hx+dx, hy+dy, 1.5
      context.strokeStyle = "#0808ff"
      context.stroke()
      
    if @pasteLocation isnt null and @pasteSelection isnt null
      [px, py]=@pasteLocation
      
      for [x,y,s] in @pasteSelection
        [sx,sy] = M.mulv T, [x+px, y+py]
        @drawCellShape context, sx+dx, sy+dy, 1
        context.strokeStyle = @getStateColor s
        context.stroke()
      
    if @selectionBox isnt null
      [[x1,y1],[x2,y2]] = @selectionBox
      context.fillStyle = "rgba(0,0,255,0.3)"
      context.fillRect x1, y1, x2-x1, y2-y1
      
    #context.save()
    #context.translate width/2, height/2
    #context.restore()

  #map "local" to "screen"
  _combinedViewMatrix: -> M.smul @scale, M.mul @viewMatrix, M.inv(@world.latticeMatrix)
  
  setPasteLocation: (localCell, selection)->
    @pasteLocation = localCell
    @pasteSelection = selection

  getStateColor: (s) -> @palette[(s-1)%@palette.length]

  setScale: (s)->
    @scale = s
    @cellSize = @cellSizeRel * s

  setCellSizeRel: (s)->
    @cellSizeRel = s
    @cellSize = @cellSizeRel*@scale
      
  drawGrid: (canvas, context, margin=0)->
    scale = @scale
    width = canvas.width
    height = canvas.height

    if @showStateNumbers
      context.font = @stateFont
      context.textAlign = "center"

    dx = width * 0.5
    dy = height * 0.5
    dxm = dx + margin
    dym = dy + margin
    

    #Combined transformation matrix, from integer lattice to screen
    T = @_combinedViewMatrix()
    invT = M.inv T

    #quad in the screen coordinates
    quad = [ [-dxm, dym], [-dxm, -dym], [dxm, -dym], [dxm, dym]]

    #transform it to the integer lattice
    iquad  = (M.mulv(invT, vi) for vi in quad)

    context.clearRect(0, 0, canvas.width, canvas.height)
    #get points and draw them

    invViewBig = B.adjoint @viewMatrixBig
    context.save()
    context.translate width/2, height/2
    convexQuadPoints iquad, (ix, iy) =>
      # [ix,iy] is in the "local" coordinates.
      # 
      #convert integer points back to screen coordinates
      [sx, sy] = M.mulv T, [ix,iy]

      cellCoord = @local2global [ix, iy]
      cellState = @world.getCell(cellCoord)
      if cellState is 0
        if @showEmpty
          context.strokeStyle =@emptyCellColor
          @drawCellShape context, sx, sy, 1
          context.stroke()        
      else
        
        if @showStateNumbers
          context.fillStyle = @getStateColor cellState
          t = ""+cellState
          context.fillText t, sx, sy
        else
          @drawCellShape context, sx, sy, 1
          context.fillStyle = @getStateColor cellState
          context.fill()
        
          
        if @showConnection and (@world.connections isnt null)
          ccell = @world.connections.get cellCoord, null

          context.strokeStyle = @connectionLineColor

          if ccell isnt null
            #iterate over alive neighbors of a cell
            for neighbor in ccell.neighbors
              #to avoid double lines
              continue if neighbor.coord.hash > cellCoord.hash
              continue if @world.getCell(neighbor.coord) is 0
              
              #find coordinates of the neighbor in screen coords
              [nix,niy] = B.mulv @viewMatrixBig, @center.offset neighbor.coord
              #if neighbor is relatively close
              if nix.isSmall and niy.isSmall
                #coordinates of the neighbor on the screen
                [nx, ny] = M.mulv T, [nix.value, niy.value]
                #draw the line
                context.beginPath()
                context.moveTo sx, sy
                context.lineTo nx, ny
                context.stroke()
    context.restore()

            
    
