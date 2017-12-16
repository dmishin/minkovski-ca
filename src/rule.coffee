"use strict"
### cellular automaton rule
###
exports.BinaryTotalisticRule = class BinaryTotalisticRule
  constructor: (rulestr) ->
    @tables = [{}, {}]
    m = /B([0-9 ]*)S([0-9 ]*)/.exec rulestr.trim()
    throw new Error("Bad rule string: #{rulestr}") unless m?

    parseTable = (tableStr) ->
      table = {}
      for part in tableStr.split " "
        continue if part is ""
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
      keys
    "B#{tablekeys(@tables[0]).join ' '} S#{tablekeys(@tables[1]).join ' '}"

  
