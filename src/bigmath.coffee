bigInt = require "big-integer"



###
#find integer sqare root using Newton method
#returns a tuple: (floor(sqrt(x)) :: LongInteger, is_exact_root :: bool)
###
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
