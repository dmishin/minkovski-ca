"use strict"
CA = require "./ca.coffee"
{World, makeCoord} = require "./world.coffee"
bigInt = require "big-integer"
{BinaryTotalisticRule} = require "./rule.coffee"

m = [2,1,1,1]
sampleNeighbor=[1,0]
R = new BinaryTotalisticRule("B3 S2 3")

fillRandom = (world, extent, percent)->

  low = extent.multiply(-1)
  
  npoints = Math.round(4*extent**2*percent) |0
  for _ in [0...npoints]
    xy = makeCoord bigInt.randBetween(low, extent), bigInt.randBetween(low, extent)
    world.setCell xy, 1
  return

maxXY = (world)->
  m = null
  update = (x)->
    if x.isNegative() : x = x.multiply(-1)
    if m is null
      m = x
    else if x.gt m
      m = x
    
  world.cells.iter (kv)->
    update kv.k.x
    update kv.k.y
  m
  
w = new World m, sampleNeighbor

experiments = []


for 

initialExtent = 10
percent = 0.2


experiment =
  extent: initialExtent*2
  percent: percent
  rule: ""+R
  gridMatrix: m
  sampleNeighbor: sampleNeighbor

fillRandom w, bigInt(initialExtent), percent
console.log(w.population())

experiment.populdation = pops = []
generation = 0
    

while true
  pops.push w.population()

  if w.population() > 1000
    console.log "Population reached #{w.population()} on step #{generation}"
    break

  CA.step w, R
  generation += 1

console.log {experiments: experiments
