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
conicsIntersection = (a, c, p, pap) ->
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


class DerivedCell
  constructor: (kv1, kv2)->
    @parents = [kv1.k, kv2.k]
    @values = [kv1.v, kv2.v]

  #put new key-value pair if it is nto present yet.
  put: (kv) ->
    index = @parents.indexOf kv
    if index is -1
      @parents.push kv.k
      @values.push kv.v
    return

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
  
#GIven a World instance, find all new cells that are not present in the world,
# and have at least 2 common neighbors with world cells
exports.newNeighbors = newNeighbors = (world) ->
  #Key is Coord instance. Value is an object:
  #   list of cells with their values that have this neighbor
  #   { neighbors: [] # list of Coord
  #     values: [] }  # list of cell values
  newCells = newCoordHash()

  #iterate over all cell pairs in the world
  iterateItemPairs world.cells, (kv1, kv2) ->
    #each kv is a hashRecord instance, with k field being Coord (key) and v is cell value
    for neighbor in commonNeighbors world.a, world.c, kv1.k, kv2.k
      #Skip neighbors that are already present i nthe woprld
      continue if world.cells.has neighbor

      newRecord = newCells.get neighbor, null
      if newRecord is null
        newCells.put neighbor, new DerivedCell kv1, kv2
      else
        #register these cells in the derived
        newRecord.put kv1
        newRecord.put kv2
        
  return newCells


#calculate generalized neighbor sum for the derived cell
connectedCellSum = (cell, rule) ->
  s = rule.foldInitial
  for neighbor in cell.neighbors
    s = rule.fold s, neighbor.value
  return s

#Evaluate one step of the world, using given rule
exports.step = ( world, rule ) ->

  connections = calculateConnections world
  oldCells = world.cells
  world.cells = newCoordHash()
  connections.iter (kv)->
    sum = connectedCellSum kv.v, rule
    state = kv.v.value

    newState = rule.next state, sum
    if newState isnt 0
      world.cells.put kv.k, newState
  return oldCells
