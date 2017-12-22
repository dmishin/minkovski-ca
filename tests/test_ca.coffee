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
    

describe "conicsIntersection2", ->
  #conicsIntersection2 = (a, c1, c2, p, pap) ->

  m = [2,1,1,1]
  a = tfm2qform m
  c1 = qform a, [1,0]
  c2 = qform a, [0,1]

  bigVec = (x,y) -> [bigInt(x), bigInt(y)]

  it "must return nothing for zero vector",->
    
    assert.deepEqual [], CA.conicsIntersection2 a, c1, c2, bigVec(0,0)
    
  it "must decompose [1,0] + [0,1]",->
    ints = CA.conicsIntersection2 a, c1, c2, bigVec(1,1)
    assert.ok ints.length>0, "Must have at least 1 intersection"
    foundExpected = false
    for [x,y] in ints
      if x.equals(1) and y.equals(0)
        foundExpected = true
    assert.ok foundExpected, "Must find point [1,0]"
      

  it "must find at least some intersections in +-100 range and they must be correct, a=#{JSON.stringify a}, c1=#{c1}, c2=#{c2}", ->
    numIntersections = 0
    numTests = 0
    for x in [-100 .. 100]
      for y in [-100 .. 100]
        numTests += 1
        p = bigVec(x,y)
        ints = CA.conicsIntersection2 a, c1, c2, p
        continue if ints.length is 0

        numIntersections += 1

        #check the intersection

        for v in ints
          assert.ok BM.qformSmallA(a,v).equals(c1), "Magnitude from (#{v[0]},#{v[1]}) to (0,0) must be #{c1}"
          assert.ok BM.qformSmallA(a,BM.subv(v,p)).equals(c2), "Magnitude from (#{v[0]},#{v[1]}) to (#{p[0]},#{p[1]}) must be #{c2}"
    assert.ok numIntersections>3, "Must find at least 3 intersection"
    assert.ok numIntersections<numTests-1, "Must has less than #{numTests-1} intersections"
  
  

  it "must return the same value as simple intersection if c1=c2, for intersections in +-100 range, a=#{JSON.stringify a}, c1=c2", ->
    
    for x in [-100 .. 100]
      for y in [-100 .. 100]
        for c in [c1,c2]
          p = bigVec(x,y)
          ints2 = CA.conicsIntersection2 a, c, c, p
          ints = CA.conicsIntersection a, c, p

          assert.equal ints2.length, ints.length
          for v in ints2
            any = false
            for v1 in ints
              if v[0].equals(v1[0]) and v[1].equals(v1[1])
                any = true
                break
            assert.ok any, "Must have one vector equal to #{v}, found none, in intersection with p=#{p}, c=#{c}, A=#{JSON.stringify a}"
    return
