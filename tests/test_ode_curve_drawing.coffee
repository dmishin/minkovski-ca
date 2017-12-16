assert = require "assert"
C = require "../src/ode_curve_drawing.coffee"

describe "drawAllBranches(A, x0, y0, x1, y1, step)", ->

  it "must generate empty graph when there are no intersections",->
    segments = C.drawAllBranches([1,0,0,1], -0.5, -0.5, 0.5, 0.5, 0.01)
    assert.equal segments.length, 0

  it "must generate single seglent when whole circle is indide",->
    segments = C.drawAllBranches([1,0,0,1], -5, -5, 5, 5, 0.01)
    assert.equal segments.length, 1
    assert.ok segments[0].length>10

  it "must generate 4 segments for circle protruding to sides",->
    segments = C.drawAllBranches([1,0,0,1], -0.9, -0.9, 0.9, 0.9, 0.01)
    assert.equal segments.length, 4
    
    assert.ok segments[0].length>10
    assert.ok segments[1].length>10
    assert.ok segments[2].length>10
    assert.ok segments[3].length>10
