M = require "./matrix2.coffee"

#find minimum by key
findMin = (arr, keyfunc) ->
  besta = arr[0]
  bestkey = keyfunc besta
  besti = 0
  for i in [1 ... arr.length]
    ai = arr[i]
    k = keyfunc ai
    if k < bestkey
      bestkey = k
      besta = ai
      besti = i
  return [besta, besti]

#intersection os segment, given by 2 points, with a horizontal line
# eq1: y1*(1-t)+y2*t =y;
# eq2: x1*(1-t)+x2*t =x;
# display2d: false;
# solve([eq1,eq2],[t,x]);
#
# returns 2 values:
#  - has intersection?
#  - intersection x coordinate
#  - y2 < y1  (if true, point is left bound, otherwise - right)
intersectSegmentWithHorizontalLine = (v1, v2, y) ->
  [x1,y1] = v1
  [x2,y2] = v2

  dy = (y2-y1)
  
  if dy is 0
    return [false, null, null]
    
  t = (y-y1)/dy

  if t < 0 or t>1
    [false, null, null]
  else
    x = x1*(1-t)+x2*t
    [true, x, y2 < y1]

#intersection of CCV polygon with H-line.
# returns flag and 3 points: left and right. 
intersectPolygonWithHorizontalLine = (vs, y) ->
  hasLeft = false
  hasRight = false
  left = null
  right = null

  tryEdge = (v1, v2) ->
    [intersected, x, isLeft] = intersectSegmentWithHorizontalLine v1, v2, y
    if intersected
      if isLeft
        left = if hasLeft then Math.max(left, x) else x
        hasLeft = true
      else
        right = if hasRight then Math.min(right, x) else x
        hasRight = true
  for i in [0...vs.length]
    tryEdge vs[i], vs[(i+1)%vs.length]

  if hasLeft and hasRight
    if left <= right
      return [true, left, right]
    else
      #allow both CW and CCW
      return [true, right, left]
  else
    return [false, null, null]
    
exports.convexQuadPoints = ( vertices, callback ) ->
  #integer points inside convex quadrilateral, given by 4 vertices
  # vertice coordinates can be non-integer.
  if vertices.length isnt 4
    throw new Error "Must have 4 vertices"
  [vtop, itop] = findMin vertices, ([_,y])->-y
  [vbottom, ibottom] = findMin vertices, ([_,y])->y
  if itop is ibottom
    #empty quadrilateral
    return

  #for each edge, determine whether it is left-slope or right-slope
  #strictly horizontal ones can be ignored

  for y in [Math.ceil(vbottom[1])|0 .. Math.floor(vtop[1])|0]  by 1
    
    [intersected, xmin, xmax] = intersectPolygonWithHorizontalLine vertices, y
    continue if not intersected
    for x in [Math.ceil(xmin)|0 .. Math.floor(xmax)|0]  by 1
      callback x, y
    
