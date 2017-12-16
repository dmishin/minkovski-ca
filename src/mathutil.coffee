"use strict"

M = require "./matrix2.coffee"
###calculate quadratic cofrm
####
exports.qform = ([a,b,c,d], [x,y])->
  x*x*a + (b+c)*x*y + y*y*d
      

###Convert identity transofrm to quadratic form matrix
###
exports.tfm2qform = ([a,b,c,d])->
    [2*c,d-a,d-a, -2*b]

