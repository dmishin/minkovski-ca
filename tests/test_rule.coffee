"use strict"
assert = require "assert"
{BinaryTotalisticRule} = require "../src/rule.coffee"

describe "BinaryTotalisticRule", ->
  it "Must support creation", ->
    assert.ok new BinaryTotalisticRule "B2S23"
    assert.ok new BinaryTotalisticRule "B2S23"
    assert.ok new BinaryTotalisticRule "   B2S23  "
    assert.ok new BinaryTotalisticRule "   B2S23"
    
  it "Must support empty lists", ->
    assert.ok new BinaryTotalisticRule "BS"
    assert.ok new BinaryTotalisticRule "B2S"
    assert.ok new BinaryTotalisticRule "B2S3"
    assert.ok new BinaryTotalisticRule "BS3"

  it "Must support string conversion", ->
    r = new BinaryTotalisticRule "B2S23"
    assert.equal "B2S23", ""+r
    
    r = new BinaryTotalisticRule "BS2"
    assert.equal "BS2", ""+r
    r = new BinaryTotalisticRule "B2S"
    assert.equal "B2S", ""+r

        
  it "Must evaluate correctly", ->
    r = new BinaryTotalisticRule "B3S23(10)"
    assert.equal r.next(0,0), 0
    assert.equal r.next(0,1), 0
    assert.equal r.next(0,2), 0
    assert.equal r.next(0,3), 1 #B3
    assert.equal r.next(0,4), 0
    assert.equal r.next(0,5), 0
    assert.equal r.next(0,6), 0

    assert.equal r.next(1,0), 0
    assert.equal r.next(1,1), 0
    assert.equal r.next(1,2), 1 #S2
    assert.equal r.next(1,3), 1 
    assert.equal r.next(1,4), 0
    assert.equal r.next(1,5), 0
    assert.equal r.next(1,6), 0

    assert.equal r.next(1,10), 1

    assert.equal r.next(1,100), 0
    
        
