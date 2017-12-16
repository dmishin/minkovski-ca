{CustomHashMap} = require "../src/hashmap.coffee"
assert = require "assert"

dummyHash = (x) -> 0
dummyEq = (x,y) -> x is y
identityHash = (x) -> x

describe "CustomHashMap.size", ->
  h = new CustomHashMap dummyHash, dummyEq
  it "must be 0 initially", ->
    assert.equal h.size(), 0
    
  it "must be 1 after putting 1 value", ->
    h.put 1, "hello"
    assert.equal h.size(), 1

  it "must still be 1 after putting 1 value with the same key", ->
    h.put 1, "hello there"
    assert.equal h.size(), 1

  it "must be 2 after putting new key", ->
    h.put 2, "hello there 2"
    assert.equal h.size(), 2

  it "must remain 2 after putting another item with the same key", ->
    h.put 2, "hello there 2-bis"
    assert.equal h.size(), 2
                

describe "CustomHashMap put/get/remove/iter", ->
  doPutGetRemoveTest = (hashFunc, eqFunc, desc) ->
    h = new CustomHashMap hashFunc, eqFunc
    
    it "must get default value when empty (#{desc})", ->
      assert.equal h.get(1, null), null
      assert.equal h.get(0, null), null
      assert.equal h.get(1000, null), null
      assert.equal h.get(-1000, null), null

    it "must return the only value put (#{desc})", ->
      h.put 1, "one"
      assert.equal h.get(1), "one"
      assert.equal h.get(0, null), null
      assert.equal h.get(1000, null), null
      assert.equal h.get(-1000, null), null
    

    it "must return the only value put (#{desc})", ->
      h.put 2, "two"
      assert.equal h.get(1), "one"
      assert.equal h.get(2), "two"
      assert.equal h.get(1000, null), null
      assert.equal h.get(-1000, null), null
    

    it "must support owerwrite value (#{desc})", ->
      h.put 1, "one-bis"
      h.put 2, "two-bis"
      assert.equal h.get(1), "one-bis"
      assert.equal h.get(2), "two-bis"

    it "must iterate over ket-value pairs (#{desc})", ->
      kvs = []
      h.iter (kv) ->
        kvs.push [kv.k, kv.v]

      kvs.sort ([k1,v1],[k2,v2])->
        if k1 < k2
          -1
        else if k1 is k2
          0
        else
          1
      
      assert.deepEqual kvs, [[1, "one-bis"],[2, "two-bis"]]
      

    it "must support remove value (#{desc})", ->
      assert h.remove 1
      assert.equal h.get(1, null), null
      assert.equal h.get(2), "two-bis"
      assert.equal h.size(), 1

      assert h.remove 2
      assert.equal h.get(1, null), null
      assert.equal h.get(2, null), null
      assert.equal h.size(), 0

    it "must not crash on remove non-existant key (#{desc})", ->
      assert not h.remove 1
      assert not h.remove 2
      assert not h.remove -1000
      assert.equal h.size(), 0

  doPutGetRemoveTest dummyHash, dummyEq, "constant hash"
  doPutGetRemoveTest identityHash, dummyEq, "identity hash"
