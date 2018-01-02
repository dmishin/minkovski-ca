"use strict"
bigInt = require "big-integer"
{bigIntHash} = require "./bigmath.coffee"
{CustomHashMap} = require "./hashmap.coffee"
{qform, tfm2qform}  = require "./mathutil.coffee"
M = require "./matrix2.coffee"
B = require "./bigmatrix.coffee"

hashCombine = (h1,h2) -> (((h1 << 5) - h1) + h2)|0


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
    if isReal
      @angle = Math.log Math.abs b
      #console.log "Pseudoangle: #{@angle}"
    else
      @angle = Math.atan2 b, a
      #console.log "Angle: #{@angle}"

    #Normalized projection of the lattice.
    vv = M.orthoDecomp @a  
    @latticeMatrix = M.mul vv, rot45
    
  setNeighborVectors: (neighborVectors)->
    @c = (qform(@a, x0) for x0 in neighborVectors)

  _sampledata: ->
    put = (x,y) => @cells.put(new Coord(bigInt(x), bigInt(y)), 1)
    put 0, 0
    put 10, 5
    put -10, 5
    put 15, 5
    put -1, -3
    put 1, 1
    put 0, 1
    put -1, 1

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
