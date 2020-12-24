"use strict"
bigInt = require "big-integer"
{bigIntHash} = require "./bigmath.coffee"
{CustomHashMap} = require "./hashmap.coffee"
{qform, tfm2qform}  = require "./mathutil.coffee"
M = require "./matrix2.coffee"
B = require "./bigmatrix.coffee"

hashCombine = (h1,h2) -> (((h1 << 5) - h1) + h2)|0
muls = (mtxs...) ->
  m = mtxs[0]
  for mi in mtxs[1..]
    m = M.mul m, mi
  return m



exports.Coord = class Coord
  constructor: (@x,@y) ->
    @hash = hashCombine(bigIntHash(@x), bigIntHash(@y))
  
  toString: -> "(#{@x},#{@y})"
  
  equals: (that) ->
    (@hash is that.hash) and (@x.equals that.x) and (@y.equals that.y)

  translate: ([dx,dy]) -> new Coord @x.add(dx), @y.add(dy)
  translateBack: ([dx,dy]) -> new Coord @x.subtract(dx), @y.subtract(dy)
  #vector from this to that
  offset: (that) -> [that.x.subtract(@x), that.y.subtract(@y)]
  
exports.makeCoord = (x,y) -> new Coord bigInt(x), bigInt(y)

rot45 = M.rot(Math.PI * -0.25)

exports.newCoordHash = newCoordHash = -> new CustomHashMap(((c)->c.hash), ((c1,c2)->c1.equals(c2)))

#for the given integer transformation matrix, returns primitive vectors of the lattice, implementing it.
# vectors are columns
calculateLattice = ([x,y,z,w])->
  i2z = 0.5/z
  s = x+w
  q = Math.sqrt(Math.abs(s*s-4.0))
  isEuclidean = Math.abs(s) < 2
  
  angle = 
  {
    T:[1.0, (w-x)*i2z, 0.0, q*i2z]
    euclidean:isEuclidean
    angle:if isEuclidean
      Math.atan2 q, s
    else
      Math.log((q+s)*0.5)
  }
  

exports.World = class World
  constructor: (skewMatrix, neighborVectors)->
    @cells = newCoordHash()
    @connections = null
    @m = skewMatrix

    #;paing matrix details
    throw new Error "matrix determinant is not 1" unless M.det(@m) is 1
    
    #calculate various lattice parameters
    @m_inv = M.adjoint @m #inverse skew matrix (adjoint is fine because det=1)
    @a = tfm2qform @m   #conic (pseudonorm) matrix.
    @setNeighborVectors neighborVectors #pseudonorm of the neighbor vector

    tr = M.tr @m
    if Math.abs(tr) is 2 then throw new Error("Degenerate case |tr(M)|=2 is not supported")
    if M.tr(@m) < -2 then throw new Error("Pseudo-rotation matrix must have positive trace")
    #parameters of the invariant (pseudo)rotation.

    #Normalized projection of the lattice.
    {T:T, euclidean:@isEuclidean, angle:@angle} = calculateLattice @m
    vv = M.inv T

    #ensure the order of vectors in the lattice matrix so that invariant rotation angle would always be positive
    if @angle < 0
      @angle = -@angle
      # rearrange order of columns and rows in r: 
      # r1 = flip * r * flip  where flip = [0 1 1 0]
      # thus vv1 = vv * flip
      flip = if @isEuclidean then [0,1,1,0] else [0,1,-1,0]
      vv = M.mul vv, flip
                  
    @latticeMatrix = vv
    

  setNeighborDistances: (neighborDistances) ->
    @c = neighborDistances
    
  setNeighborVectors: (neighborVectors)->
    @c = (qform(@a, x0) for x0 in neighborVectors)

  setCell: (coord, state) ->
    if state is 0
      @cells.remove coord
    else
      @cells.put coord, state
    return

  putPattern: (coord, celllist)->
    for xys in celllist
      @setCell coord.translate(xys), xys[2]
    return

  #convenience toggle method.
  toggle: (coord, state=1) ->
    old = @cells.get coord, 0
    if old isnt state
      @cells.put coord, state
    else
      @cells.remove coord if old isnt 0
      
  getCell: (coord) ->
    @cells.get coord, 0

  #vector pseudonorm
  pnorm2: (bigVec) -> B.qformSmallA @a, bigVec
  
  #pseudo-distance between 2 coordinates
  pdist2: (coord1, coord2) -> @pnorm2 coord1.offset(coord2)
    
  clear: ->
    @cells = newCoordHash()
    @connections = null
    this

  population: -> @cells.size()

  getCellList: ->
    cl = []
    @cells.iter (kv)->
      cl.push [kv.k.x, kv.k.y, kv.v]
    return cl


exports.cellList2Text = (cells)->("#{x} #{y} #{s}" for [x,y,s] in cells).join(";")
exports.sortCellList = (cells)->
  cells.sort (vals1, vals2)->
    for v1, i in vals1
      v2 = vals2[i]
      cmp = v1.compare v2
      return cmp if cmp isnt 0
    return 0
  return cells

exports.centerCellList = (cells)->
  return cells if cells.length is 0
  for [x,y,_], i in cells
    if i is 0
      sx = x
      sy = y
    else
      sx = sx.add x
      sy = sy.add y
  cx = sx.divide cells.length
  cy = sy.divide cells.length
  #console.log "CEnter #{cx}, #{cy}"
  for [x,y,s] in cells
    [x.subtract(cx), y.subtract(cy), s]

exports.parseCellList = (text)-> _parseCellListImpl text, (s)->parseInt(s,10)
exports.parseCellListBig = (text)-> _parseCellListImpl text, bigInt

_parseCellListImpl = (text, intParser)->
  console.log text
  for part in text.split ";" when part
    m = /(-?\d+)\s+(-?\d+)\s+(\d+)/.exec part.trim()
    if m is null then throw new Error("Bad format of cell list: #{part}")
    x = intParser m[1]
    y = intParser m[2]
    s = parseInt m[3], 10
    [x,y,s]

