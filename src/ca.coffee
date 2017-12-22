"use strict"
bigInt = require "big-integer"
{qform, tfm2qform}  = require "./mathutil.coffee"
{Coord, newCoordHash} = require "./world.coffee"
M = require "./matrix2.coffee"
BM = require "./bigmatrix.coffee"
{sqrt, possibleSquare} = require "./bigmath.coffee"

### Finds integer intersection of two conics x'Ax=c, separated by vector p
#   if no intersecitons found, returns null
#   a - small matrix
#   p - big vector
#   c - small number
###
exports.conicsIntersection = conicsIntersection = (a, c, p, pap) ->
  #console.log {P:p}

  pap = pap ? BM.qformSmallA a, p
    
  if pap.isZero() then return []
    
  da = M.det(a)
  ra = BM.tobig M.mul [0, -1, 1, 0], a

  Dnum = bigInt(4*c).subtract(pap)
  Dden = pap.multiply(da)
  #console.log {pap:pap, "|a|":da, num: Dnum, den: Dden}

  #one root, single neighbor
  if Dnum.isZero()
    return if p[0].isOdd() or p[1].isOdd()
      []
    else
      [[p[0].divide(2), p[1].divide(2)]]
      
  #move sign to the numerator.
  if Dden.isNegative()
    Dnum = Dnum.negate()
    Dden = Dden.negate()
  
  if Dnum.isNegative()
    return [] #no solutions at all

  #simplify the fraction, or else we can't take square root for sure.
  g = bigInt.gcd Dnum, Dden
  Dnum = Dnum.divide g
  Dden = Dden.divide g
  #console.log {gcd:g, num: Dnum, den: Dden}

  #calculate its root
  #first, quick ckeck. mut increase performance, but I don't conw for true.
  return [] if not possibleSquare(Dnum) or not possibleSquare(Dden)
  #then, real calculation  
  [qnum, isExactSquare] = sqrt(Dnum) #big root
  
  if not isExactSquare
    #not a full square
    return []
    
  [qden, isExactSquare] = sqrt(Dden)
  if not isExactSquare
    #not a fu;ll square again
    return []
  #console.log {qnum:qnum, qden: qden}
  
  [rapx, rapy] = BM.smul(qnum, BM.mulv(ra, p))

  #console.log {rapx:rapx, rapy:rapy}
  
  {quotient:rapx1, remainder:m} = rapx.divmod qden
  
  if not m.isZero() then return []
    
  {quotient:rapy1, remainder:m} = rapy.divmod qden
  if not m.isZero() then return []

  #console.log {rapx1:rapx1, rapy1:rapy1}

    
  twox1 = [p[0].add(rapx1), p[1].add(rapy1)]
  if twox1[0].isOdd() or twox1[1].isOdd()
    return []
    
  #if one vector is divisible by 2, then the other one is divisible too, no need to check
  twox1 = [twox1[0].divide(2), twox1[1].divide(2)]
  twox2 = [p[0].subtract(rapx1).divide(2), p[1].subtract(rapy1).divide(2)]
  #console.log {twox1:twox1, twox2:twox2}
  return [twox1, twox2]

### Intersection of 2 different conics:
#   x'Ax = c1
#   (x-p)'A(x-p) = c2
#
#   Returns 1 or 2 integer solutions or empty list, if no.
#
# \frac{
#    p(c_1-c_2 + pap) + q\sqrt{
#        -\frac1{da}\left((pap-c_1-c_2)^2-4c_1c_2\right)
#    }
#  }{
#    2 pap
#  }
###
exports.conicsIntersection2 = conicsIntersection2 = (a, c1, c2, p, pap) ->
  pap = pap ? BM.qformSmallA a, p
  if pap.isZero() then return []
    
  da = M.det(a)
  ra = BM.tobig M.mul [0, -1, 1, 0], a

  #expression under the root
  # 1/da * ((pap-c_1-c_2)^2-4c_1c_2)
  r = pap.subtract(c1+c2).square().subtract(4*c1*c2)

  if ((da<0) and r.isNegative()) or ((da>0) and r.isPositive())
    return []
    
  #console.log "r is = #{r}"
  if r.isZero()
    #special case of single intersection (touching hyperboloids or ellipses)
    #
    # p(c_1-c_2 + pap) / (2pap)
    v = divIntVector BM.smul(pap.add(c1-c2), p), pap.multiply(2)
    return if v is null then [] else [v]
  
  #divide by -da. if not divisible - no solution
  {quotient:rda, remainder:rem} = r.divmod -da
  return [] unless rem.isZero()

  #calculate quare root
  [sqrt_rda, isExactSquare] = sqrt rda
  return [] unless isExactSquare

  #coeff before p
  # c_1-c_2 + pap
  alpha = pap.add(c1-c2)

  #finally, calculate the vector
  scaled_p = BM.smul alpha, p
  
  scaled_q = BM.smul sqrt_rda, BM.mulv(ra, p)

  #and their sum must be divisible by 2 pap
  pap2 = pap.multiply 2

  ret = []
  v = divIntVector BM.addv(scaled_p,scaled_q), pap2
  ret.push v if v isnt null
  v = divIntVector BM.subv(scaled_p,scaled_q), pap2
  ret.push v if v isnt null

  return ret
    
divIntVector = ([x,y], k)->
  {quotient: xk, remainder: r} = x.divmod(k)
  return null unless r.isZero()
  {quotient: yk, remainder: r} = y.divmod(k)
  return null unless r.isZero()
  [xk, yk]
  
#Find common neighbors of 2 cells. List of either 0, 1 or 2 Coord instances.
# pap is optional, magnitude of the coord1-coord2 vector
exports.commonNeighbors = commonNeighbors = (A, c, coord1, coord2, pap) ->
  v = coord1.offset coord2
  #now try to decompose v into sum of 2 vectors of norm xAx == c.
  decomp = conicsIntersection A, c, v, pap
  (coord1.translate(vi) for vi in decomp)

#calls callback function for all different key-value pairs in the CustomHashMap
exports.iterateItemPairs = iterateItemPairs = (customHashMap, onCellPair) ->
  previous = []
  customHashMap.iter (kv) ->
    for kv1 in previous
      onCellPair kv, kv1
    previous.push kv

class ConnectedCell
  #coord is stored for drawing purposes. ALso, to use "is" to check for equality. WIth coord, real equality check is needed.
  constructor: (@coord, @value)->
    @neighbors = [] #list of neighbor ConnectedCells
    
  addNeighborIfNotYet: (n)->
    if @neighbors.indexOf(n) is -1
      @neighbors.push n
      true
    else
      false
  removeNeighbor: (n)->
    idx = @neighbors.indexOf n
    if idx isnt -1
      @neighbors.splice idx, 1
    else
      throw new Error "Attempt to remove neighbor that is already removed"
  #calculate generalized neighbor sum for the derived cell
  sum: (rule) ->
    s = rule.foldInitial
    for neighbor in @neighbors
      s = rule.fold s, neighbor.value
    s

#Takes world and calculates enriched structure, where each cell knows its neighbors
# and initially empty cells with 2 or more neighbors are present.
#
# Returned value is hash map with Coord key and ConnectedCell value
exports.calculateConnections = calculateConnections = (world)->
  #key is coord, value is ConnectedCell
  connections = newCoordHash()

  previous = []

  world.cells.iter (kv) ->
    #found a non-empty cell. it *must* be not present yet in the conencted map.
    richCell = new ConnectedCell kv.k, kv.v
    connections.put kv.k, richCell
    # Now iterate all other cells that were visited before this.
    for richCell2 in previous
      # first find neighbors. To do this, calculate interval
      # offset vector from the original cell to this.
      dv = kv.k.offset richCell2.coord

      # magniture of the distance vector, bigint.
      mag = world.pnorm2 dv

      if mag.equals world.c
        #if it is a neighbor, it must be a new neighbor. registe the connection without additional checks
        richCell.neighbors.push richCell2
        richCell2.neighbors.push richCell
      
      #also, these 2 cells might have common neighbor.
      # (is it possible when they are neighbors? At least, for some grids (hexagonal) it is true.
      for dv1 in conicsIntersection world.a, world.c, dv, mag
        neighborCoord = kv.k.translate dv1
        #found at least 1 common neighbor.
        # ignore it if it is one of the old cells
        continue if world.cells.has neighborCoord
        #OK, this neighbor referes to the previously empty place.
        # is it present in the rich map?
        richNeighborCell = connections.get neighborCoord
        if not richNeighborCell?
          #when it is not registered yet, then do it
          richNeighborCell = new ConnectedCell neighborCoord, 0
          connections.put neighborCoord, richNeighborCell
          #and add its parents as neighbors, without checking.
          richNeighborCell.neighbors.push richCell
          richNeighborCell.neighbors.push richCell2
          richCell.neighbors.push richNeighborCell
          richCell2.neighbors.push richNeighborCell
        else
          #so, maybe this neighbor was already obtained as a neighbor of some other cells
          # in this case, register neighbors with a care
          if richNeighborCell.addNeighborIfNotYet richCell
            richCell.neighbors.push richNeighborCell
          if richNeighborCell.addNeighborIfNotYet richCell2
            richCell2.neighbors.push richNeighborCell
      #done processing neighbors
    #done cycle over previous cells
    previous.push richCell
  #Done. Now return connections map
  connections  
  

#Evaluate one step of the world, using given rule
exports.step = ( world, rule ) ->

  connections = calculateConnections world
  oldCells = world.cells
  world.cells = newCoordHash()
  world.connections = connections
  
  connections.iter (kv)->
    sum = kv.v.sum rule
    state = kv.v.value

    newState = rule.next state, sum
    if newState isnt 0
      world.cells.put kv.k, newState
    #store new value in the new state too, in order to simplify neighbor calculation
    #kv.v.value = newState
  return oldCells
