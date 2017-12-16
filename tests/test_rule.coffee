"use strict"
assert = require "assert"
{BinaryTotalisticRule} = require "../src/rule.coffee"

describe "BinaryTotalisticRule", ->
  it "Must support creation", ->
    assert.ok new BinaryTotalisticRule "B2 S2 3"
    assert.ok new BinaryTotalisticRule "B 2 S 2 3"
    assert.ok new BinaryTotalisticRule "   B 2 S 2 3  "

    assert.ok new BinaryTotalisticRule "   B   2  S  2 3  "    

  it "Must support string conversion", ->
    r = new BinaryTotalisticRule "B2 S2 3"
    assert.equal "B2 S2 3", ""+r
    
  it "Must evaluate correctly", ->
    r = new BinaryTotalisticRule "B3 S2 3 10"
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
    
        
