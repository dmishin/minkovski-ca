"use strict"
#Operations on 2x2 matrices
# Matrices stored as arrays, row by row
bigInt = require "big-integer"

exports.eye = eye = -> [bigInt[1], bigInt[0], bigInt[0], bigInt[1]]
exports.diag = diag = (a,b) -> [a, bigInt[0], bigInt[0], b]
exports.zero = zero = -> [bigInt[0], bigInt[0], bigInt[0], bigInt[0]]
exports.set = set = (m,i,j,v) ->
  m[i*2+j]=v
  return m

exports.tobig = tobig = (m) -> (bigInt(mi) for mi in m)
exports.eq = eq = (m1,m2) ->
  for m1i, i in m1
    m2i = m2[i]
    return false unless m1i.eq(m2i) 
  true
  
exports.mul = mul = (m1, m2) ->
  m = zero()
  for i in [0...2]
    for j in [0...2]
      s = bigInt[0]
      for k in [0...2]
        s = s.add( m1[i*2+k].multiply(m2[k*2+j]) )
      m[i*2+j] = s
  return m
  
exports.copy = copy = (m) -> m[..]

exports.mulv = mulv = (m, v) ->
  [m[0].multiply(v[0]).add(m[1].multiply(v[1])),
   m[2].multiply(v[0]).add(m[3].multiply(v[1]))]

exports.adjoint = adjoint = (m) -> [m[3], m[1].negate(), m[2].negate(), m[0]]

exports.smul = smul = (k, m) -> (mi.multiply(k) for mi in m)
exports.add = add = (m1, m2) -> (m1[i].add(m2[i]) for i in [0...4])
exports.sub = sub = (m1, m2) -> (m1[i].subtract(m2[i]) for i in [0...4])

exports.addScaledInplace = addScaledInplace = (m, m1, k) ->
  for i in [0...m.length]
    m[i] =  m[i].add(m1[i].multiply(k))
  return m
  
exports.transpose = transpose = (m)->
  [m[0], m[2],
   m[1], m[3]]
  
###  array of matrix powers, from 0th to (n-1)th
###
exports.powers = (matrix, n) ->
  #current power
  m_n= eye()
  
  pows = [m_n]
  for i in [1...n]
    m_n = mul matrix, m_n
    pows.push m_n
  return pows


### Calcualte eigenvectors
###    
exports.det = det = (m)->
  [a,b,c,d] = m
  a.multiply(d).subtract(b.multiply(c))

exports.fromColumns = fromColumns = ([a,b],[c,d]) -> [a,c,b,d]
exports.toColumns = toColumns = ([a,c,b,d]) -> [[a,b],[c,d]]

exports.qformSmallA = ([a,b,c,d],[x1, x2]) ->
  y1 = x1.multiply(x1).multiply(a)
  y2 = x1.multiply(x2).multiply(b+c)
  y3 = x2.multiply(x2).multiply(d)

  y1.add(y2).add(y3)

exports.addv = ([x1,x2], [y1,y2]) -> [x1.add(y1), x2.add(y2)]
exports.subv = ([x1,x2], [y1,y2]) -> [x1.subtract(y1), x2.subtract(y2)]

exports.pow = pow = (m, n) ->
  if n < 0
    throw new Error("Won't calculate negative power now")
  if n is 0
    eye()
  else if n is 1
    m
  else
    mp2 = pow(m, n >> 1)
    mp = mul mp2, mp2
    if n & 0x1
      mul m, mp
    else
      mp
    
exports.tr = tr = (m) -> m[0].add m[3]
