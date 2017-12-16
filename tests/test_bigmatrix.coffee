assert = require "assert"
bigInt = require "big-integer"


M = require "../src/bigmatrix"


describe "eq", ->
  it "must return true for equal matrices", ->
    assert.ok M.eq M.tobig([0,0,0,0]), M.tobig([0,0,0,0])

  it "must return false for significantly in equal matrices", ->
    m1 = M.tobig [0,0,0,0]
    for i in [0...4]
      m2 = M.tobig [0,0,0,0]
      m2[i] = 1.0
      assert.ok not M.eq m1, m2
      

describe "eye", ->
  it "msut equal unit matrix", ->
    m = (bigInt[0] for i in [0...4])
    
    for i in [0...2]
      M.set m, i, i, bigInt[1]

    assert.ok M.eq(m, M.eye())

describe "mul", ->
  it "must multiply eye to itself", ->
    assert.ok M.eq M.eye(), M.mul(M.eye(), M.eye())

  it "must return same non-eye matrix, if multiplied with eye", ->
    m = M.tobig (i for i in [0...4])

    assert.ok M.eq m, M.mul(m, M.eye())
    assert.ok M.eq m, M.mul(M.eye(), m)

  it "must change non-eye matrix if squared", ->
    m = M.tobig (i for i in [0...4])
    assert.ok not M.eq m, M.mul(m, m)


describe "smul", ->
  it "must return 0 if multiplied by 0", ->
    assert.ok M.eq M.zero(), M.smul( bigInt[0], M.eye())

  it "must return same if multiplied by 1", ->
    assert.ok M.eq M.eye(), M.smul( bigInt[1], M.eye())

describe "addScaledInplace", ->
  it "must modify matrix inplace", ->
    m = M.eye()
    m1 = M.tobig [1,1,1, 1]

    M.addScaledInplace m, m1, 1
    expect = M.tobig [2,1,1, 2]
    assert.ok M.eq expect, m

  it "must add with coefficient", ->
    m = M.eye()
    m1 = M.tobig [1, 1,1,1]

    M.addScaledInplace m, m1, -2
    expect = M.tobig [-1,-2,-2, -1]
    assert.ok M.eq expect, m
        
        
describe "powers", ->
  
  it "must return array of N first powers of a matrix", ->

    a = M.tobig [1,2,
                 3,-1]

    pows3 = M.powers a, 4

    assert.equal pows3.length, 4

    assert.ok M.eq pows3[0], M.eye()
    assert.ok M.eq pows3[1], a
    assert.ok M.eq pows3[2], M.mul(a,a)
    assert.ok M.eq pows3[3], M.mul(a,M.mul(a,a))
    

describe "diag", ->
  it  "must return diagonal matrix", ->
    assert.ok M.eq M.diag(bigInt[1],bigInt[2]), M.tobig [1, 0, 0, 2]
    assert.ok M.eq M.diag(bigInt[3],bigInt[1]), M.tobig [3, 0, 0, 1]
    
assertVecEq = (xx,yy)->
  for xi, i in xx
    yi = yy[i]
    assert.ok xi.equals(yi), "Element #{i}: #{xi} != #{yi}"
  return
  
describe "addv", ->
  it "must add 2 big vectors", ->
    assertVecEq M.tobig([1,1]), M.addv(M.tobig([0,1]), M.tobig([1,0]))
    assertVecEq M.tobig([10,20]), M.addv(M.tobig([-10,10]), M.tobig([20,10]))
  it "must add big and small vectors", ->
    assertVecEq M.tobig([1,1]), M.addv(M.tobig([0,1]), [1,0])
    assertVecEq M.tobig([10,20]), M.addv(M.tobig([-10,10]), [20,10])
    

describe "pow", ->
  it "must return eye for eye powers", ->
    assert.ok M.eq M.eye(), M.pow M.eye(), 0
    assert.ok M.eq M.eye(), M.pow M.eye(), 1
    assert.ok M.eq M.eye(), M.pow M.eye(), 10
    assert.ok M.eq M.eye(), M.pow M.eye(), 10000
    
  it "must raise error for negative power", ->
    assert.throws ->
      M.pow M.eye(), -1

  it "must calculate non-eye powers",->
    m = M.tobig [-1, 2, 3, 4]
    mi = M.eye()
    for i in [0..100]
      assert.ok M.eq mi, M.pow(m, i), "#{i}th power of #{JSON.stringify m} must be #{JSON.stringify mi}"
      mi = M.mul m, mi
      
      
