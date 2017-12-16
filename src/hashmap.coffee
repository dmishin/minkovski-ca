#Hash map that uses chain as key
class HashPair
  constructor: (@k, @v) ->
  map: (mapfunc) -> new HashPair(@k, mapfunc @v)
  
exports.CustomHashMap = class CustomHashMap
  constructor: (@hashfunc, @equal) ->
    @map = {}
    @_size = 0
    
  put: (key, value) ->
    h = @hashfunc(key).toString(16)
    
    if @map.hasOwnProperty h
      vals = @map[h]
      pair = @_findPair vals, key
      if pair is null
        vals.push new HashPair key, value
        @_size += 1
      else
        pair.v = value
    else
      @map[h] = [ new HashPair(key, value) ]
      @_size += 1
    this

  has: (key)->
    h = @hashfunc(key).toString(16)
    if @map.hasOwnProperty h
      @_findPair(@map[h], key) isnt  null
    else
      false
  get: (key, defval)->
    h = @hashfunc(key).toString(16)
    if @map.hasOwnProperty h
      pair = @_findPair @map[h], key
      if pair is null
        defval
      else
        pair.v
    else
      defval
    
  remove: (key) ->
    h = @hashfunc(key).toString(16)
    if @map.hasOwnProperty h
      vals = @map[h]
      i = @_findPairIndex vals, key
      if i is -1
        false
      else
        vals.splice i, 1
        @_size -= 1
        true
    else
      false
            
  _findPair: (values, key) ->
    for pair in values
      if (pair.k is key) or @equal(pair.k, key)
        return pair
    null
    
  _findPairIndex: (values, key) ->
    for pair, i in values
      if (pair.k is key) or @equal(pair.k, key)
        return i
    -1
  size: -> @_size
  iter: (cb)->
    for _, pairs of @map
      for pair in pairs
        cb pair
    return
  

  mapValues: (mapfunc) ->
    mapped = new CustomHashMap @hashfunc, @equal    
    for hash, pairs of @map
      mapped.map[hash] = (kv.map(mapfunc) for kv in pairs)
    return mapped
