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
exports.commonNeighbors = commonNeighbors = (A, c, coord1, coord2) ->
  v = coord1.offset coord2
  #now try to decompose v into sum of 2 vectors of norm xAx == c.
  decomp = conicsIntersection A, c, v
  (coord1.translate(vi) for vi in decomp)



#calls callback function for all different key-value pairs in the CustomHashMap
iterateItemPairs = (customHashMap, onCellPair) ->
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
derivedCellSum = (dcell, rule) ->
  s = rule.foldInitial
  for value in dcell.values
    s = rule.fold s, value
  return s

worldCellSum = (coord, world, rule) ->
  s = rule.foldInitial
  world.cells.iter (kv) ->
    if world.pdist2(kv.k, c) is world.c
      0

#Evaluate one step of the world, using given rule
exports.step = ( world, rule ) ->

  newState = newCoordHash()

  #find new neighbors
  newOnes = newNeighbors world


  #iterate over new cells, because we already have parents for them
  newOnes.iter (kv) ->
    sum = derivedCellSum kv.v, rule
    newCellState = rule.next 0, sum
    if newCellState isnt 0
      newState.put kv.k, newCellState

  #iterate over existing cells
  world.cells.iter (kv) ->
    
