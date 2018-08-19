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
    
    
  setNeighborVectors: (neighborVectors)->
    @c = (qform(@a, x0) for x0 in neighborVectors)

  setCell: (coord, state) ->
    if state is 0
      @cells.remove coord
    else
      @cells.put coord, state
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
