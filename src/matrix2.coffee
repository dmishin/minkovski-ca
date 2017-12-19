"use strict"
#Operations on 2x2 matrices
# Matrices stored as arrays, row by row

exports.eye = eye = -> [1.0, 0.0, 0.0, 1.0]
exports.diag = diag = (a,b) -> [a, 0.0, 0.0, b]
exports.zero = zero = -> [0.0, 0.0, 0.0, 0.0]
exports.set = set = (m,i,j,v) ->
  m[i*2+j]=v
  return m

exports.rot = rot = (angle) ->
  m = eye()
  s = Math.sin angle
  c = Math.cos angle
  return [c, -s, s, c]

exports.hrot = hrot = (sinhD) ->
  m = eye()
  s = sinhD
  c = Math.sqrt( sinhD*sinhD + 1 )
  return [c,s,s,c]


exports.mul = mul = (m1, m2) ->
  m = zero()
  for i in [0...2]
    for j in [0...2]
      s = 0.0
      for k in [0...2]
        s += m1[i*2+k] * m2[k*2+j]
      m[i*2+j] = s
  return m


exports.approxEq = approxEq = (m1, m2, eps=1e-6)->
  d = 0.0
  for i in [0...m1.length]
    d += Math.abs(m1[i] - m2[i])
  return d < eps

exports.copy = copy = (m) -> m[..]

exports.mulv = mulv = (m, v) ->
  [m[0]*v[0] + m[1]*v[1],
   m[2]*v[0] + m[3]*v[1]]

exports.approxEqv = approxEqv = (v1, v2, eps = 1e-6) ->
  d = 0.0
  for i in [0...2]
    d += Math.abs(v1[i] - v2[i])
  return d < eps

###
# m: matrix( [m0, m1, m2], [m3,m4,m5], [m6,m7,m8] );
# ratsimp(invert(m)*determinant(m));
# determinant(
###
exports.inv = inv = (m) ->
  #Calculated with maxima
  iD = 1.0 / det(m)
  smul iD, adjoint(m)

exports.adjoint = adjoint = (m) -> [m[3], -m[1], -m[2], m[0]]


exports.smul = smul = (k, m) -> (mi*k for mi in m)
exports.add = add = (m1, m2) -> (m1[i]+m2[i] for i in [0...4])
exports.addScaledInplace = addScaledInplace = (m, m1, k) ->
  for i in [0...m.length]
    m[i] += m1[i]*k
  return m
  
  
exports.transpose = transpose = (m)->
  [m[0], m[2],
   m[1], m[3]]
  
exports.amplitude = amplitude = (m) -> Math.max (Math.abs(mi) for mi in m) ...

    
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


exports.eig = eig = (m)->
  #returns 3 values
  # (true, e1, e2)
  # (false, re(e), im(e)
  [a,b,c,d] = m
  # pp - (a+d)p + ad-bc
  bb = a+d
  cc = det m
  D = 0.25*bb**2-cc
  
  if D < 0
    [false, 0.5*bb, Math.sqrt(-D)]
  else
    q = Math.sqrt(D)
    [true, 0.5*bb - q, 0.5*bb + q]
    
### Calcualte eigenvectors
###
    
exports.det = det = (m)->
  [a,b,c,d] = m
  a*d - b*c

eivgRealOne = (m, lam)->
  m1 = m[...]
  addScaledInplace m1, eye(), -lam
  [a,b,c,d] = m1
  if b**2 + a**2 > d**2 + c**2
    [b, -a]
  else
    [d, -c]
          
exports.eigvReal = eigvReal = (m, lam1, lam2) ->
  [eivgRealOne(m, lam1), eivgRealOne(m, lam2)]

exports.fromColumns = fromColumns = ([a,b],[c,d]) -> [a,c,b,d]
exports.toColumns = toColumns = ([a,c,b,d]) -> [[a,b],[c,d]]


#Given symmetrix matrix S return new matrix such that
# v' s v = diag(+-1)
exports.orthoDecomp = (s)->
  [isReal, sigma1, sigma2] = eig s
  
  if Math.abs(sigma1 - sigma2) > 1e-6    
    [v1, v2] = eigvReal(s, sigma1, sigma2)    
    v = fromColumns normalized(v1), normalized(v2)
  else
    v = eye()

  d1 = 1.0 / Math.sqrt(Math.abs(sigma1))
  d2 = 1.0 / Math.sqrt(Math.abs(sigma2))
  mul v, diag(d1,d2)


exports.len2 = len2 = ([x,y]) -> x**2+y**2
exports.normalized = normalized = (v) -> smul 1.0/Math.sqrt(len2 v), v
exports.dot = ([x1,y1],[x2,y2]) -> x1*x2+y1*y2
exports.vcombine = ([x1,y1], k, [x2,y2]) -> [x1+k*x2, y1+k*y2]
  
exports.equal = equal = (u,v) ->
  for ui, i in u
    if ui isnt v[i] then return false
  return true
