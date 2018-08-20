"use strict"
CA = require "./ca.coffee"
{World, makeCoord, cellList2Text, sortCellList, centerCellList} = require "./world.coffee"
bigInt = require "big-integer"
B = require "./bigmatrix.coffee"
{BinaryTotalisticRule} = require "./rule.coffee"

gridMatrix = [2,1,1,1]
sampleNeighbors=[[1,0],[2,0]] #1 0;1 -1;1 1; 0 1
R = new BinaryTotalisticRule("B4 S2 3 4")
initialExtent = 7
percent = 0.06

showPercent = false

MAX_PERIOD = 200

isInteresting = (p, isSpaceship)->
  return isSpaceship or (p is -1)


console.log "Rule is: #{R}"
console.log "Lattice matrix: #{JSON.stringify gridMatrix}" 
console.log "Neighborhood: #{JSON.stringify sampleNeighbors}"

fillRandom = (world, extent, percent)->

  low = extent.multiply(-1)
  
  npoints = Math.round(4*extent**2*percent) |0
  for _ in [0...npoints] by 1
    xy = makeCoord bigInt.randBetween(low, extent), bigInt.randBetween(low, extent)
    world.setCell xy, 1
  return

maxXY = (world)->
  m = null
  update = (x)->
    if x.isNegative()
      x = x.multiply(-1) 
    if m is null
      m = x
    else if x.gt m
      m = x
    
  world.cells.iter (kv)->
    update kv.k.x
    update kv.k.y
  return m
  

cmpCellList = (l1, l2)->
  return false if l1.length isnt l2.length
  for [x,y,s], i in l1
    [x1,y1,s1] = l2[i]
    return false unless (x.eq(x1) and y.eq(y1) and (s is s1))
  return true

#returns null is patterns not equal; othervise - translation vector

patternsEqual = (pattern1, pattern2)->
  return null if pattern1.length isnt pattern2.length
  return [bigInt[0], bigInt[0]] if pattern1.length is 0
  delta = ([x1,y1,...], [x2,y2,...])-> [x2.subtract(x1), y2.subtract(y1)]
  deltaEq = ([x1,y1],[x2,y2])->       x1.equals(x2) and y1.equals(y2)
  
  for p1, i in pattern1
    p2 = pattern2[i]
    if i is 0
      d = delta p2, p1
    else
      return null unless deltaEq d, delta p2, p1      
  return d

transformCellList = (m, cells)->
  tfmCell = ([x,y,v])->
    [x1,y1] = B.mulv m, [x,y]
    [x1,y1,v]
  cells.map tfmCell

analyzePeriod = (world, rule)->
  initial = sortCellList world.getCellList()
  period = -1
  for p in [1..MAX_PERIOD] by 1
    CA.step world, rule
    cells = sortCellList(world.getCellList())

    translation = patternsEqual cells, initial
    if translation isnt null
      period = p
      break

  isSpaceship = (translation isnt null) and not (translation[0].isZero() or translation[1].isZero())
  if isSpaceship
    {v:translation, rotation: rotation} = normalizeTranslation translation, world
    initial = transformCellList rotation, initial
  
  console.log "Period:#{period} v=(#{translation[0]},#{translation[1]}) |v|^2=#{world.pnorm2 translation}\t#{cellList2Text centerCellList initial}" if isInteresting(period, isSpaceship)


#tries to find a rotataion that minimizes the vector
normalizeTranslation = (v, world)->
  m0 = B.tobig world.m
  m1 = B.adjoint m0
  
  criterion = (v)->
    x = v[1].abs().multiply(10).add(v[0].abs().multiply(2))
    if v[1].isNegative()
      #prefer positive to negative
      x = x.add(1)
    return x

  v0 = v
  v1 = B.mulv m0, v0
  
  c0 = criterion v0
  c1 = criterion v1

  if c1.lesser c0
    #direction m0 is good
    direction = m0
    rotation = m0
  else
    #direction m1 is good
    [c0,c1] = [c1,c0]
    [v0,v1] = [v1,v0]
    direction = m1
    rotation = B.eye()

  while true
    v0 = v1
    c0 = c1
    v1 = B.mulv direction, v0
    c1 = criterion v1
    break unless c1.lesser c0
    rotation = B.mul rotation, direction

  [x,y] = v0
  if (x.isNegative() and not y.isPositive()) or (y.isNegative() and not x.isPositive())
    flip = [-1,0,0,-1]
    rotation = B.mul rotation, flip
    v0 = [x.negate(),y.negate()]

  #at this point, v0, c0 are the best candidates, and rotation stores the rotation
  return {v: v0, rotation: rotation}


percentstep = 1.01

while true
  w = new World gridMatrix, sampleNeighbors
  fillRandom w, bigInt(initialExtent), percent
  generation = 0
      

  resolution = null
  while true
    if w.population() > 100
      resolution = 'highpop'
      break
    if w.population() is 0
      resolution = 'die'
      break
    if generation > 200
      resolution = 'methusela'
      break
    CA.step w, R
    generation += 1
  
  console.log "#{resolution}, p=#{percent}" if showPercent
    

  if resolution is 'highpop'
    #console.log "exploded, #{generation}, #{w.population()}"
    percent /= percentstep
  else if resolution is 'die'
    #console.log "death, #{generation}"
    percent *= percentstep
  else if resolution is 'methusela'
    #console.log "methusela"
    analyzePeriod(w, R)
    
