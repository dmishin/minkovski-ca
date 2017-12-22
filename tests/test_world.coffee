{Coord, makeCoord, World} = require "../src/world.coffee"
bigInt = require "big-integer"
assert = require "assert"


describe "Coord", ->

  it "Must support creation", ->

    c = makeCoord 10, 20

    assert.ok c.x.equals bigInt[10]
    assert.ok c.y.equals bigInt[20]
    

    c1 = makeCoord "10000000000000000000000000", "999999999999999999999"
    assert.ok c1.x.equals bigInt("10000000000000000000000000")
    assert.ok c1.y.equals bigInt("999999999999999999999")
    
  it "SUpports string conversion", ->
    c = makeCoord 10, "10000000000"
    assert.equal ""+c, "(10,10000000000)"

  it "SUpports equality comparison", ->
    c1 =    makeCoord 10, 20
    c1bis = makeCoord 10, 20
    c2 =    makeCoord "10000000000000000000000000", "999999999999999999999"
    c2bis = makeCoord "10000000000000000000000000", "999999999999999999999"
    c3 =    makeCoord 10, "10000000000"
    c3bis = makeCoord 10, "10000000000"

    assert.ok c1.equals c1
    assert.ok c1.equals c1bis
    assert.ok c1bis.equals c1

    assert.ok c2.equals c2bis

    assert.ok c3.equals c3bis

    assert.ok not c1.equals c2
    assert.ok not c1.equals c3

    assert.ok not c2.equals c1
    assert.ok not c2.equals c3

    assert.ok not c3.equals c1
    assert.ok not c3.equals c2
                
describe "World", ->
  it "must support creation with corrrect parameters", ->

    assert.doesNotThrow ->  new World [2, 1, 1, 1], [[1,0]]
    assert.doesNotThrow ->  new World [0, 1, -1, 0], [[1,0]]

  it "must raise error with incorrect skew matrix", ->
    assert.throws -> new World [1,1,1,1], [[1,0]]
    assert.throws -> new World [1,2,-1,1], [[1,0]]
    assert.throws -> new World [1,0,0,1], [[1,0]]

  
