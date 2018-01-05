{drawAllBranches} = require "./ode_curve_drawing.coffee"
M = require "./matrix2.coffee"
$ = require "jquery"

canvas = $("#canvas").get(0)
ctx = canvas.getContext "2d"

pad0 = (nchars, n)->
  s = ""+n
  while s.length < nchars
    s = "0"+s
  return s

savedContext = (ctx, func)->
  ctx.save()
  try
    rval = func()
  finally
    ctx.restore()
  return rval
  
linspace = (a,b,n)->
  s = (b-a)/n
  (a+s*i for i in [0...n])
  
animateRotations = ->
  nframes = 100
  canvas.width = 480
  canvas.height = 240
  paths = [
    {
      color: "black"
      points: [[70,0],[0, -70], [-70,0], [0, 70]]
      width: 2
      close: true
    },
    {
      color: "blue"
      points: ([Math.cos(a)*20, Math.sin(a)*20] for a in linspace(0,2*Math.PI,100))
      width: 2
      close:true
    },
    {
      color: "green"
      points: ([Math.cosh(a)*20, Math.sinh(a)*20] for a in linspace(-Math.log(70/20),Math.log(70/20),100))
      width: 2
      close:false
    },

    {
      color: "green"
      points: ([-Math.cosh(a)*20, -Math.sinh(a)*20] for a in linspace(-Math.log(70/20),Math.log(70/20),100))
      width: 2
      close:false
    },
  ]
  
  margin = 10
  size = Math.min((canvas.width*0.5) | 0, canvas.height) - margin
  
  height = canvas.height
  drawPath = (path, tfm)->
    ctx.strokeStyle = path.color ? "#000"
    ctx.lineWidth = path.width ? 1
    ctx.beginPath()
    for xy, i in path.points
      [x,y] = M.mulv tfm, xy
      ctx.lineTo x, y
    if path.close
      ctx.closePath()
    ctx.stroke()

  arrowW = 10
  arrowH = 5
  drawAxes = ->
    ctx.beginPath()
    ctx.translate 0.5, 0.5
    #horizontal
    ctx.moveTo -0.5*size, 0
    ctx.lineTo  0.5*size, 0
    
    ctx.moveTo  0.5*size-arrowW, -arrowH
    ctx.lineTo  0.5*size, 0
    ctx.lineTo  0.5*size-arrowW,  arrowH

    #vertical
    ctx.moveTo 0, -0.5*size
    ctx.lineTo 0,  0.5*size
    
    ctx.moveTo -arrowH,  -(0.5*size-arrowW)
    ctx.lineTo  0,  -0.5*size
    ctx.lineTo  arrowH,  -(0.5*size-arrowW)
    
    ctx.strokeStyle = "#888"
    ctx.lineWidth = 1
    ctx.stroke()
    ctx.translate -0.5, -0.5
            
  drawConics = (A, radii)->
    savedContext ctx, ->
      ctx.lineWidth = 1
      ctx.setLineDash [5, 5]
      for radius in radii
        ctx.strokeStyle = "#faa"
        drawHyperbola M.smul 1.0/(radius**2), A
        ctx.strokeStyle = "#aaf"
        drawHyperbola M.smul -1.0/(radius**2), A
        
  drawHyperbola = (A)->
    for part in drawAllBranches(A, -0.5*size, -0.5*height, 0.5*size, 0.5*height, 0.1)
      ctx.beginPath()
      for [x,y] in part
        ctx.lineTo x, y
      ctx.stroke()
      
  drawFrame = (angle)->
    ctx.fillStyle = "#fff"
    ctx.fillRect 0, 0, canvas.width, canvas.height
    savedContext ctx, ->
      ############################
      tfm = [Math.cos(angle), -Math.sin(angle), Math.sin(angle), Math.cos(angle)]
      ctx.translate canvas.width*0.25|0, canvas.height*0.5|0
      drawAxes()
      radii = [70,20]#(r for r in [0 .. size*0.75] by 20)      
      drawConics [1, 0, 0, 1], radii
      for path in paths
        drawPath path, tfm
      ########################
      ctx.translate ((canvas.width*0.5)|0), 0
      drawAxes()
      tfm = [Math.cosh(angle), Math.sinh(angle), Math.sinh(angle), Math.cosh(angle)]
      drawConics [1, 0, 0, -1], radii
      for path in paths
        drawPath path, tfm
      return

  runUpload = (step)->
    if step is nframes
      console.log "Uploads done"
      return
    angle = Math.sin(step / nframes * 2 * Math.PI)
    drawFrame angle
    uploadToServer "animate-rotation-#{pad0 4, step}.png", (ajax)->
      if ajax.status isnt 200
        console.log "Error"
        console.log ajax
      else
        runUpload step+1
  runUpload(0)
    
getAjax = ->
  if window.XMLHttpRequest?
    return new XMLHttpRequest()
  else if window.ActiveXObject?
    return new ActiveXObject("Microsoft.XMLHTTP")

uploadToServer = (imgname, callback)->
  cb = (blob) ->
    formData = new FormData()
    formData.append "file", blob, imgname
    ajax = getAjax()
    ajax.open 'POST', '/uploads/', false
    ajax.onreadystatechange = -> callback(ajax)
    ajax.send(formData)
  canvas.toBlob cb, "image/png"

  
  
$("#btn-run-rotations").on 'click', -> animateRotations()
