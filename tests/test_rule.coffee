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
