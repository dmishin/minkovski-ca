bigInt = require "big-integer"

#disable native bigint, because it causes performance degradation in small int case, which is the most common.
supportsNativeBigInt = false;#typeof BigInt === "function";

if not supportsNativeBigInt
###
#find integer sqare root using Newton method
#returns a tuple: (floor(sqrt(x)) :: LongInteger, is_exact_root :: bool)
###
#old implementation
  exports.sqrt = (x)->
    if x.isNegative()
      throw new Error "Negative argument"
     if x.isSmall
      q = Math.floor(Math.sqrt x.value) |0
      [bigInt(q), q*q is x.value]
    else
      sqrtBig x

  exports.bigIntHash = (x)->
    if x.isSmall
      x.value
    else
      hash = if x.sign then 0 else 1
      for part in x.value
        hash  = (((hash << 5) - hash) + part)|0
      hash

  sqrtBig = (x)->
    #rough estimate of the square root magnitude
    # this uses the fact that BigInteger stores value as a groups of 7 decimal digits. 
    xi = bigInt(10).pow((x.value.length * 7 / 2)|0)

    while true
      {quotient: q, remainder: r} = x.divmod xi
      xi1 = xi.add(q).divide(2)
      d = xi1.minus xi
      xi = xi1
      break if d.isSmall and (d.value is 0 or d.value is 1)
      
    [xi, r.isZero()]

  # returns True if X can be square
  possibleSquares = do ->
    sqs = {}
    p = 10000
    for x in [0...p]
      sqs[(x*x)%p] = true
    sqs

      
  exports.possibleSquare = (x) ->
    if x.isNegative() then return false
    possibleSquares.hasOwnProperty if x.isSmall
      (x.value % 10000)
    else
      (x.value[0] % 10000)
else
  #New implementation that works with bigints  
  exports.sqrt = (x_)->
    x = x_.value
    if x < 0
      throw new Error "Negative argument"
     if small x
      sx = Number x
      q = Math.floor(Math.sqrt sx) |0
      [bigInt(q), q*q is sx]
    else
      sqrtBig x

  exports.bigIntHash = (x_)->
    x = x_.value
    if small x
      Number x
    else
      if x < 0
        hash = 1
        x = -x
      else
        hash = 0
      while x    
      #for part in x.value
        part = Number(x & 0xffffffffffffn) #48 bits
        x = x >> 48n
        hash  = (((hash << 5) - hash) + part)|0
      hash

  small = (x) -> x<=Number.MAX_SAFE_INTEGER and x>=Number.MIN_SAFE_INTEGER
    
  sqrtBig = (x)->
    #rough estimate of the square root magnitude
    # this uses the fact that BigInteger stores value as a groups of 7 decimal digits.
    xi = 1n
    while true
      r = x % xi
      xi1 = (xi + x/xi )>>1n
      d = xi1 - xi
      xi = xi1
      break if (d is 0n or d is 1n)
      
    [bigInt(xi), r is 0n]

  # returns True if X can be square
  possibleSquares = do ->
    sqs = (false for _ in [0...256])
    for x in [0...256]
      sqs[(x*x)%256] = true
    sqs
      
  exports.possibleSquare = (x_) ->
    x = x_.value
    if x<0
      false
    else
      possibleSquares[x & 0xffn]
