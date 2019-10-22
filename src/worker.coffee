"use strict"
M = require "./matrix2.coffee"
{convexQuadPoints} = require "./geometry.coffee"
{qform, tfm2qform}  = require "./mathutil.coffee"
{World, makeCoord, cellList2Text, sortCellList, parseCellList, parseCellListBig}= require "./world.coffee"
CA = require "./ca.coffee"
{BinaryTotalisticRule, CustomRule} = require "./rule.coffee"
bigInt = require "big-integer"


onmessage = (e)->
  [msg, data] = e.data
  postMessage try
    switch
      when msg is "render" then renderDataImpl(data...)
      else throw new Error "unknown message #{msg}"
  catch e
    ['error', ""+e]
    	      
renderDataImpl = (ruleType, ruleCode, skewMatrix, neighbors, cells)->
  #first convert everything to the native objects
  rule = switch
    when ruleType is "BinaryTotalisticRule" then new BinaryTotalisticRule ruleCode
    when ruleType is "CustomRule" then new CustomRule ruleCode
    else throw new Error("Bad rule type #{ruleType}")

  world = new World skewMatrix, []
  world.setNeighborDistances neighbors

  for [x,y,s] in cells
    world.setCell makeCoord(x,y), s

  CA.step world, rule

  cells = []
  world.cells.iter (kv)->
      cells.push [""+kv.k.x, ""+kv.k.y, kv.v]
  ['OK', cells]

self.addEventListener('message', onmessage, false)
console.log("Worker started")

