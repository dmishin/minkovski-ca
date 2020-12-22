assert = require "assert"

bigInt = require "big-integer"

{sqrt, bigIntHash, possibleSquare} = require "../src/bigmath.coffee"

describe "sqrt", ->
  it "must work with small ints", ->

    [y, exact] = sqrt(bigInt 0)
    assert.ok y.equals bigInt(0)
    assert.ok exact

    [y, exact] = sqrt(bigInt 1)
    assert.ok y.equals bigInt(1)
    assert.ok exact
    
    [y, exact] = sqrt(bigInt 9)
    assert.ok y.equals bigInt(3)
    assert.ok exact

    [y, exact] = sqrt(bigInt 10)
    assert.ok y.equals bigInt(3)
    assert.ok not exact

    [y, exact] = sqrt(bigInt 99)
    assert.ok y.equals bigInt(9)
    assert.ok not exact

  it "must work with square big ints", ->
    [y, exact] = sqrt(bigInt(10).pow(100))
    console.log ["sqrtbig is", y, exact]
    assert.ok y.equals bigInt(10).pow(50)
    assert.ok exact

    [y, exact] = sqrt(bigInt('1237493919283891298318928384716263674712').pow(2))
    assert.ok y.equals bigInt('1237493919283891298318928384716263674712')
    assert.ok exact

  it "must work with non-square big ints", ->
    [y, exact] = sqrt(bigInt(10).pow(100).add(1000) )
    assert.ok y.equals bigInt(10).pow(50)
    assert.ok not exact

    [y, exact] = sqrt(bigInt(10).pow(100).subtract(1000) )
    assert.ok y.equals bigInt(10).pow(50).subtract(1)
    assert.ok not exact


    [y, exact] = sqrt(bigInt('1237493919283891298318928384716263674712').pow(2).add(1000) )
    assert.ok y.equals bigInt('1237493919283891298318928384716263674712')
    assert.ok not exact
    

    [y, exact] = sqrt(bigInt('1237493919283891298318928384716263674712').pow(2).subtract(199999000) )
    assert.ok y.equals bigInt('1237493919283891298318928384716263674711')
    assert.ok not exact

                    
  it "must wirk in some buggy cases", ->
    [r, exact] = sqrt bigInt(3129)
    assert.equal r, 55
    assert.ok not exact

describe "bigIntHash", ->
  it "must work for small",->
    assert.ok bigIntHash(bigInt 0) isnt bigIntHash(bigInt 1)
    assert.ok bigIntHash(bigInt 0) is  bigIntHash(bigInt 0)
    assert.ok bigIntHash(bigInt -10) is  bigIntHash(bigInt -10)
    assert.ok bigIntHash(bigInt -10) isnt  bigIntHash(bigInt 10)
    assert.ok bigIntHash(bigInt -10) isnt  bigIntHash(bigInt 9)

  it "must work for big too",->
    assert.ok bigIntHash(bigInt '1111111111111111111111111111111111') isnt bigIntHash(bigInt '2222222222229999999933333333')
    assert.ok bigIntHash(bigInt '2222222222229999999933333333') is  bigIntHash(bigInt '2222222222229999999933333333')
    assert.ok bigIntHash(bigInt '-2222222222229999999933333333') is  bigIntHash(bigInt('2222222222229999999933333333').multiply(-1) )
    assert.ok bigIntHash(bigInt '-2222222222229999999933333333') isnt  bigIntHash(bigInt '2222222222229999999933333333')

  it 'must be integer', ->

    h = bigIntHash bigInt 0
    assert.equal h, h|0

    h = bigIntHash bigInt -100
    assert.equal h, h|0

    h = bigIntHash bigInt 100001
    assert.equal h, h|0

    h = bigIntHash bigInt "100000033333338888884444444441111111118888833333337777777"
    assert.equal h, h|0

describe "possibleSquare", ->
  it "must return True for small int squares", ->

    for i in [0..100]
      assert.ok possibleSquare(bigInt (i**2)), "Must be True for #{i}**2 = #{i**2}"
    assert.ok possibleSquare bigInt 7000**2
    assert.ok possibleSquare bigInt 9001**2
    
  it "must return True for big int squares", ->
    assert.ok possibleSquare bigInt('1111111111111111111111111111111111111111').pow(2)
    assert.ok possibleSquare bigInt('777').pow(20)
    assert.ok possibleSquare bigInt('9').pow(30)
    for i in [1..100]
      assert.ok possibleSquare bigInt('123123123123123123123123').add(i).pow(2)
    

  it "must return not more than half of Trues for range 0..1000",->
    trues = 0
    for x in [0..1000]
      if possibleSquare(bigInt x)
        trues += 1
    assert.ok trues < 500

  it "must return not more than half of Trues for large range",->
    trues = 0
    k = bigInt("23612461236123123112331209995233488581626366617288381723676123")
    b = bigInt("1239129323747112237")
    for x in [0..1000]
      xx = k.multiply(x).add(b)
      if possibleSquare(xx)
        trues += 1
    assert trues < 500
