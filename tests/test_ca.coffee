"use strict"
assert = require "assert"
bigInt = require "big-integer"

CA = require "../src/ca.coffee"
{Coord, makeCoord} = require "../src/world.coffee"
M = require "../src/matrix2.coffee"
BM = require "../src/bigmatrix.coffee"
{qform, tfm2qform} = require "../src/mathutil.coffee"
{CustomHashMap} = require "../src/hashmap.coffee"

describe "commonNeighbors", ->

  M = [2, 1, 1, 1]
  A = tfm2qform M
  x0 = [1,0]
  c = qform A, x0
  
  it "must return empty list for 2 equal cells", ->

    assert.deepEqual [], CA.commonNeighbors A, c, makeCoord(0,0), makeCoord(0,0)
    assert.deepEqual [], CA.commonNeighbors A, c, makeCoord(10,0), makeCoord(10,0)
    assert.deepEqual [], CA.commonNeighbors A, c, makeCoord(100,2000), makeCoord(100,2000)

    assert.deepEqual [], CA.commonNeighbors A, c, makeCoord("111111111111111","222222222222222222222222222222222222222"),makeCoord("111111111111111","222222222222222222222222222222222222222")

  it "must decompose coordinates in simple cases", ->
    
    v1 = [34,21]
    v2 = [5,-8]

    c1 = makeCoord(v1 ...)
    c2 = makeCoord(v2 ...)

    c12 = c1.translate v2

    #console.log {c12: c12}
    d12 = CA.commonNeighbors(A,c, c12, makeCoord(0,0))
    assert.equal 2, d12.length
    #console.log {D12:""+d12}
    [d1,d2]=d12
    assert.ok (d1.equals(c1) and d2.equals(c2)) or (d1.equals(c2) and d2.equals(c1))
    
  it "must decompose single neighbor case", ->

    v1 = [34,21]
    c1 = makeCoord(v1 ...)

    c11 = c1.translate v1

    d11 = CA.commonNeighbors(A,c, c11, makeCoord(0,0))
    assert.equal 1, d11.length
    
    assert.ok d11[0].equals(c1)
    
  it "must not decompose [-100, -75], bad case", ->
    origin = makeCoord 0,0
    neighbors = CA.commonNeighbors A, c, origin, makeCoord(-100, -75)
    assert.deepEqual [], neighbors
    
  it "must decompose correctly: distances must be correct", ->

    origin = makeCoord 0,0

    pdist = (v1, v2) -> BM.qformSmallA A, v1.offset(v2)
    hadAnyNeighbor = false
    for ix in [-100 .. 100]
      for iy in [-100 .. 100]
        cell = makeCoord ix, iy

        neighbors = CA.commonNeighbors A, c, origin, cell
        
        for neigh, i in neighbors
          hadAnyNeighbor = true
          assert.equal ""+c, ""+pdist(origin, neigh), "Distance from neighbor ##{i} = #{neigh} between origin:#{origin} and cell:#{cell} to origin must be #{c}"
          assert.equal ""+c, ""+pdist(cell, neigh), "Distance from neighbor ##{i} = #{neigh} between origin:#{origin} and cell:#{cell} to cell must be #{c}"
          
    assert.ok hadAnyNeighbor
  

describe "iterateItemPairs", ->
  idHash = (x) -> x
  idEq = (x,y) -> x is y
  
  it "must give nothing with empty hash map", ->
    h = new CustomHashMap idHash, idEq
    CA.iterateItemPairs h, (kv1,kv2)->
      assert.fail "Got callback with args: #{JSON.stringify [kv1, kv2]}"
  it "must give nothing with map with 1 element too", ->
    h = new CustomHashMap idHash, idEq
    h.put 1, "hello"
    CA.iterateItemPairs h, (kv1,kv2)->
      assert.fail "Got callback with args: #{JSON.stringify [kv1, kv2]}"
      
  it "must invoke callback only once for map with 2 elemns",->
    h = new CustomHashMap idHash, idEq
    h.put 1, "hello"
    h.put 2, "there"
    callNumber = 0
    CA.iterateItemPairs h, (kv1,kv2)->
      if kv2.k < kv1.k
        [kv2,kv1] = [kv1,kv2]
      assert.deepEqual kv1, {k:1, v:"hello"}
      assert.deepEqual kv2, {k:2, v:"there"}
      callNumber += 1
    assert.equal callNumber, 1
    
