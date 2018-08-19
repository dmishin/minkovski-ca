assert = require "assert"

M = require "../src/matrix2"

describe "inv", ->
  it "must invert matrix", ->
    m = [1,2,3,4]
    im = M.inv m
    iim = M.inv im
    
    assert.ok not M.approxEq m, im

    mim = M.mul m, im
    assert.ok M.approxEq mim, M.eye()
    
    imm = M.mul im, m
    assert.ok M.approxEq imm, M.eye()

    assert.ok M.approxEq iim, m
    

describe "approxEq", ->
  it "must return true for equal matrices", ->
    assert.ok M.approxEq [0,0,0,0], [0,0,0,0]

  it "must return false for significantly in equal matrices", ->
    m1 = [0,0,0,0]
    for i in [0...4]
      m2 = [0,0,0,0]
      m2[i] = 1.0
      assert.ok not M.approxEq m1, m2
      

describe "eye", ->
  it "msut equal unit matrix", ->
    m = (0.0 for i in [0...4])
    
    for i in [0...2]
      M.set m, i, i, 1.0

    assert.ok M.approxEq(m, M.eye())

describe "mul", ->
  it "must multiply eye to itself", ->
    assert.ok M.approxEq M.eye(), M.mul(M.eye(), M.eye())

  it "must return same non-eye matrix, if multiplied with eye", ->
    m = (i for i in [0...4])

    assert.ok M.approxEq m, M.mul(m, M.eye())
    assert.ok M.approxEq m, M.mul(M.eye(), m)

  it "must change non-eye matrix if squared", ->
    m = (i for i in [0...4])
    assert.ok not M.approxEq m, M.mul(m, m)


describe "rot", ->
  it "must return eye if rotation angle is 0", ->
    assert.ok M.approxEq M.eye(), M.rot(0.0)
    assert.ok M.approxEq M.eye(), M.rot(0.0)
    assert.ok M.approxEq M.eye(), M.rot(0.0)
  it "must return non-eye if rotation angle is not 0", ->
    assert.ok not M.approxEq M.eye(), M.rot(1.0)


describe "smul", ->
  it "must return 0 if multiplied by 0", ->
    assert.ok M.approxEq M.zero(), M.smul( 0.0, M.eye())

  it "must return same if multiplied by 1", ->
    assert.ok M.approxEq M.eye(), M.smul( 1.0, M.eye())

describe "addScaledInplace", ->
  it "must modify matrix inplace", ->
    m = M.eye()
    m1 = [1,1,1, 1]

    M.addScaledInplace m, m1, 1
    expect = [2,1,1, 2]
    assert.ok M.approxEqv expect, m

  it "must add with coefficient", ->
    m = M.eye()
    m1 = [1,1,1, 1,1,1, 1,1,1]

    M.addScaledInplace m, m1, -2
    expect = [-1,-2,-2, -1]
    assert.ok M.approxEqv expect, m
        
describe "amplitude", ->
  it "must return maximal absolute value of matrix element", ->
    m = [1,2,3,4]
    assert.equal M.amplitude(m), 4

    m = [1,-2,3,-4]
    assert.equal M.amplitude(m), 4

    m = [-9,2,3,4]
    assert.equal M.amplitude(m), 9

    m = [9,-2,3,-4]
    assert.equal M.amplitude(m), 9

    m = [-3,2,3,9]
    assert.equal M.amplitude(m), 9

    m = [3,-2,3,-9]
    assert.equal M.amplitude(m), 9
                                


        
describe "powers", ->
  
  it "must return array of N first powers of a matrix", ->

    a = [1,2,
         3,-1]

    pows3 = M.powers a, 4

    assert.equal pows3.length, 4

    assert.ok M.approxEq pows3[0], M.eye()
    assert.ok M.approxEq pows3[1], a
    assert.ok M.approxEq pows3[2], M.mul(a,a)
    assert.ok M.approxEq pows3[3], M.mul(a,M.mul(a,a))
    

describe "eig", ->
  it "must return 1,1 for eye", ->
    [real, e1,e2] = M.eig(M.eye())
    assert.ok real
    assert.ok M.approxEq [e1,e2], [1.0, 1.0]

  it "must return 0,0 for zero", ->
    [real, e1,e2] = M.eig(M.zero())
    assert.ok real
    assert.ok M.approxEq [e1,e2], [0.0, 0.0]

  it "must return 1,2 for diagonal matrix", ->
    [real, e1,e2] = M.eig([2.0, 0, 0, 1.0])
    assert.ok real
    assert.ok M.approxEq [e1,e2], [1.0, 2.0]

describe "eigvReal", ->
  m = [1, 2, 3, 4]
  [_, l1, l2] = M.eig m
  [v1, v2] = M.eigvReal m, l1, l2
  
  it "must return nonzero vectors", ->
    assert.ok not M.approxEq(v1, [0.0, 0.0])
    assert.ok not M.approxEq(v2, [0.0, 0.0])
    
  it "must return non-equal vectors", ->
    assert.ok not M.approxEq(v1, v2)
    
  it "must return eigenvectors", ->
    mv1 = M.mulv m, v1
    assert.ok M.approxEq mv1, M.smul(l1, v1)

    mv2 = M.mulv m, v2
    assert.ok M.approxEq mv2, M.smul(l2, v2)

describe "diag", ->
  it  "must return diagonal matrix", ->
    assert.ok M.approxEq M.diag(1,2), [1, 0, 0, 2]
    assert.ok M.approxEq M.diag(3,1), [3, 0, 0, 1]

describe "tr", ->
  it "must return matrix trace", ->
    assert.ok Math.abs(M.tr([1,2,3,4]) - 5) < 1e-6
    assert.ok Math.abs(M.tr([4,5,3,1]) - 5) < 1e-6

describe "orthoDecomp", ->
  checkOrthoDecomp = (m) ->
    v = M.orthoDecomp m
    [s1,s2,s3,s4] = M.mul(M.mul(M.transpose(v), m), v)
    assert.ok Math.abs(Math.abs(s1)-1) < 1e-6
    assert.ok Math.abs(s2) < 1e-6
    assert.ok Math.abs(s3) < 1e-6
    assert.ok Math.abs(Math.abs(s4)-1) < 1e-6
    
  it "must decompose identity matrix", ->
    checkOrthoDecomp M.eye()
    
  it "must decompose diagonal positive defined matrix", ->
    checkOrthoDecomp M.diag(4, 9)

  it "must decompose nonzero matrix", ->
    checkOrthoDecomp [2, 1, 1, -2]
    checkOrthoDecomp [2, 1, 1, 2]
