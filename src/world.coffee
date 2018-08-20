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

exports.World = class World
  constructor: (skewMatrix, neighborVectors)->
    @cells = newCoordHash()
    @connections = null
    @m = skewMatrix

    #;paing matrix details
    throw new Error "matrix determinant is not 1" unless M.det(@m) is 1
    
    #calculate various lattice parameters
    [isReal, a, b] = M.eig @m
    
    @m_inv = M.adjoint @m #inverse skew matrix (adjoint is fine because det=1)
    @a = tfm2qform @m   #conic (pseudonorm) matrix.
    @c = (qform(@a, x0) for x0 in neighborVectors)  #pseudonorm of the neighbor vector

    if M.det(@a) is 0 then throw new Error("Quadratic norm matrix is degenerate: #{JSON.stringify @a}")

    #parameters of the invariant (pseudo)rotation.
    @isEuclidean = not isReal
    #if isReal
    #  @angle = Math.log Math.abs b
    #  #console.log "Pseudoangle: #{@angle}"
    #else
    #  @angle = Math.atan2 b, a
    #  #console.log "Angle: #{@angle}"

    #Normalized projection of the lattice.
    vv = M.orthoDecomp @a
    #Now calculate angle (euclidean or pseudo-euclidean, by which multiplication by M rotates
    # the lattice in the normalized projection
    #
    # vv' a vv = diag(+-1)
    #
    # let Y is normalized coordinate system (where rotation is straight)
    #
    # Y' diag(+-1) Y = Y' vv' a vv Y
    #
    # thus X = vv Y  (X is integer coordinate)
    #
    # rotation is then: Y1 = vv^-1 X1 = VV^-1 M X = VV^-1 M VV Y
    #
    # therefore rotation matrix in Y spae is VV^-1 M VV
    r = M.mul M.inv(vv), M.mul @m, vv
    #this matrix is either rotation or pseudo-rotation
    #console.log "Rotation matrix:"
    #console.log r

    if @isEuclidean
      cos = (r[0]+r[3])*0.5
      sin = (r[1]-r[2])*0.5
      @angle = Math.atan2 sin, cos
    else
      cosh = (r[0]+r[3])*0.5
      sinh = (r[1]+r[2])*0.5
      exp =cosh + sinh
      @angle = Math.log exp

    #ensure the order of vectors in the lattice matrix so that invariant rotation angle would always be positive
    
    if @angle < 0
      @angle = -@angle
      # rearrange order of columns and rows in r: 
      # r1 = flip * r * flip  where flip = [0 1 1 0]
      # thus vv1 = vv * flip
      flip = if @isEuclidean then [0,1,1,0] else [0,1,-1,0]
      vv = M.mul vv, flip


                  
    @latticeMatrix = M.mul vv, rot45

    #normalize rows of the lattice matrix
    [v1,u1,v2,u2] = @latticeMatrix
    [v1,v2] = M.normalized [v1,v2]
    [u1,u2] = M.normalized [u1,u2]
    @latticeMatrix = [v1,u1,v2,u2]
    
    #console.log "screen rotation by M before 45 deg rotation is:"
    #console.log muls M.inv(vv), @m, vv
    #console.log "screen rotation by M after 45 deg rotation is:"
    #console.log muls M.inv(@latticeMatrix), @m, @latticeMatrix
    
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

