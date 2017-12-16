assert = require "assert"



{convexQuadPoints} = require "../src/geometry.coffee"

quadPointsAsArray = (vs) ->
  pts = []
  convexQuadPoints vs, (x,y) -> pts.push [x,y]
  return pts

describe "convexQuadPoints", ->
  bigDiamondCCW = [ [5,5], [0,5], [-5,0], [0, -5] ]
  smallDiamondCCW = [ [0.5,0.5], [0,0.5], [-0.5,0], [0, -0.5] ]


  it "must return many points in big diamond", ->
    pts = quadPointsAsArray bigDiamondCCW

    assert.ok (pts.length > 1)
    
  
  it "must return one point in small diamond", ->
    pts = quadPointsAsArray smallDiamondCCW
    assert.deepEqual pts, [[0,0]]

    
    
  
