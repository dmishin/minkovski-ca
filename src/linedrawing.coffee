exports.calcStraightLine = ([x1,y1],[x2,y2]) ->
    coordinatesArray = []
    # Define differences and error check
    dx = Math.abs(x2 - x1)
    dy = Math.abs(y2 - y1)
    sx = if (x1 < x2) then 1 else -1
    sy = if (y1 < y2) then 1 else -1
    err = dx - dy
    # Set first coordinates
    coordinatesArray.push [x1,y1]
    # Main loop
    while (!((x1 is x2) and (y1 is y2)))
      e2 = err << 1
      if (e2 > -dy) 
        err -= dy
        x1 += sx
      if (e2 < dx)
        err += dx
        y1 += sy
      # Set coordinates
      coordinatesArray.push [x1,y1]
      
    # Return the result
    coordinatesArray
