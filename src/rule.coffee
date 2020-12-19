"use strict"
### cellular automaton rule
###
exports.BinaryTotalisticRule = class BinaryTotalisticRule
  states: 2
  constructor: (rulestr) ->
    @tables = [{}, {}]
    m = /B([0-9\(\)]*)\/?S([0-9\(\)]*)/i.exec rulestr.trim()
    throw new Error("Bad rule string: #{rulestr}") unless m?

    parseTable = (tableStr) ->
      table = {}
      for part in tableStr.match(/\d|\(\d+\)/g) ? []
        if part[0] is "("
          part = part.substring(1, part.length-1)
        key = parseInt part, 10
        throw new Error "Bad neighbor sum #{part}" if key isnt key
        table[key] = 1
      return table

    @tables[0] = parseTable m[1]
    @tables[1] = parseTable m[2]
  next: (state, sumNeighbors) -> @tables[state][sumNeighbors] ? 0

  #totalistic folding
  foldInitial: 0
  fold: (prev, neighborValue) -> prev + neighborValue
  
  toString : ->
    tablekeys = (table) ->
      keys = (parseInt(key,10) for key, _ of table)
      keys.sort (a,b)->a-b
      for k in keys
        if k<10
          ""+k
        else
          "("+k+")"
    return "B#{tablekeys(@tables[0]).join ''}/S#{tablekeys(@tables[1]).join ''}"
  begin: ->
  end: ->
  

exports.CustomRule = CustomRule = class
  constructor: (@code)->
    try
      codeobj = eval '('+@code+')'
    catch err
      throw new Error "Bad syntax in rule code: #{err}"
    unless codeobj.next?
      throw new Error "State evaluation function 'next' not defined"

    #put cudeobj method to self
    for field, value of codeobj
      if codeobj.hasOwnProperty field
        this[field] = value
    
  #totalistic folding. could be overloaded by rule
  foldInitial: 0
  fold: (prev, neighborValue) -> prev + neighborValue
    
  toString : -> @code

  #Callbacks for user support
  begin: ->
  end: ->
    
