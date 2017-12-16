# coding: utf-8
"use strict"
M = require "./matrix2.coffee"

#roots of a quadratic equation. 2, 1 or 0 values. includes degenerate case a=0
roots2 = (a,b,c)->
  if Math.abs(a) < 1e-14 #almost zero
    return [- c/b]
  d = b*b-4*a*c
  if d <= 0
    return []
  qd = Math.sqrt(d)
  return [(-b+qd)/(2*a), (-b-qd)/(2*a)]

#Find intersections of a centered quadratic curve x'Ax=1 with rectangle.
rectangleIntersections = ( x0, y0, x1, y1, A)->
  intersections = [] #(point, normal vector) list
  [a,b,b1,c] = A
  b += b1
  
  #x = x0, y in (y0, y1)
  # ax0^2 + b*x0*y + c*y^2 = 1  
  for y in roots2( c, b*x0, a*x0*x0-1 )
    if y0 <=  y and y <= y1
      intersections.push( [[x0, y], [1, 0]] )
  for y in roots2( c, b*x1, a*x1*x1-1 )
    if y0 <= y and y <= y1
      intersections.push( [[x1, y], [-1, 0]] )
  
  #y = y0, x in (x0, x1)
  # ax0^2 + b*x0*y + c*y^2 = 1  
  for x in roots2( a, b*y0, c*y0*y0-1 )
    if x0 < x and x < x1
      intersections.push( [ [x, y0], [0, 1] ] )
  for x in roots2( a, b*y1, c*y1*y1-1 )
    if x0 < x and x < x1
      intersections.push( [ [x, y1], [0, -1] ] )
  
  return intersections

### Generate points along a quadratic curve, starting at the given point
###
points = ( A, x0, directionVector, step, onPoint)->
  x = x0
  R = [0, -1,1, 0] #rotation by 90 matrix
  dA = M.det(A)
  
  #calculate initia direction.
  v0 = M.mulv R, M.mulv A, x0
  if M.dot(v0, directionVector) < 0
    #direciton should be reversed
    step = -step
  
  #start generating points
  x = x0
  #curvature compensated step. why sqrt??? it works well though.
  correctedStep = step/Math.sqrt(Math.abs(dA))
  
  while true
    p = M.mulv A, x   #normal vector
    v = M.mulv R, p   #tangent vector
    delta = M.dot(p,x) - 1  #error
    pp = M.dot(p,p)
    
    k = -0.5 * delta / pp    
    qpp = Math.sqrt(pp)
    
    x = M.vcombine x, k, p                 #correction step
    x = M.vcombine x, correctedStep, v     #step along the curve
    break if onPoint(x)
  return
        
drawNonIntersectingEllipse = (A,x0,y0,x1,y1, step)->
  #find intersections with y=0 line
  xx0 = Math.sqrt(1.0 / A[0])
  if x0 <= xx0 and xx0 <= x1
    #we have one point inside the area: (xx0, 0)    
    segment = [[xx0, 0]]
    was1stQuad = true
    points A, [xx0,0], [0,1], step, (xy)->
      #stop when it changes sign to the (+,+) again
      is1stQuad = xy[0] > 0 and xy[1] > 0
      if is1stQuad and not was1stQuad
        return true #break the loop
      was1stQuad = is1stQuad
      segment.push xy
      false #continue loop
    [segment]
  else
    []

#a quick distance function.    
dist = ([x1,y1],[x2,y2])->Math.abs(x1-x2)+Math.abs(y1-y2)
  
exports.drawAllBranches = (A, x0, y0, x1, y1, step)->
  intersections = rectangleIntersections(x0, y0, x1, y1, A)
  if intersections.length is 0 and M.det(A)>0
    #special case: ellipse completely inside the rectangle.
    return drawNonIntersectingEllipse(A,x0,y0,x1,y1, step)

  #map of used points
  used = (false for _ in intersections)
  
  #console.log("Found #{intersections.length} intersections")
  
  removeIntersectionPoint = (xy)->
    ibest = null
    dbest = null
    for [xy_i, _], i in intersections
      if used[i] then  continue
      d = dist(xy_i, xy)
      if (ibest is null) or (d < dbest)
        dbest = d
        ibest = i
    if ibest is null
      console.log "Warning: odd numberof intersection points"
    else
      used[ibest] = true
    
  isOutside = ([x,y]) -> x < x0 or x > x1 or y < y0 or y > y1

  segments = []    
  for [startPoint, directionVector], i in intersections
    continue if used[i] 
    used[i] = true
    #console.log("Starting segment at #{i} : #{startPoint}")
    segment = [startPoint]
    segments.push segment
    points A, startPoint, directionVector, step, (xy)->
      segment.push xy
      if isOutside(xy)
        #end branch
        removeIntersectionPoint(xy)
        true #break the loop
      else
        false #continue loop
      

  return segments

