{drawAllBranches} = require "./ode_curve_drawing.coffee"
{convexQuadPoints} = require "./geometry.coffee"

{CustomRule} = require "./rule.coffee"
{View} = require "./view.coffee"
{World, makeCoord, cellList2Text, sortCellList, parseCellList, parseCellListBig}= require "./world.coffee"
CA = require "./ca.coffee"

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

drawHyperbola = (A, size)->
  for part in drawAllBranches(A, -0.5*size, -0.5*size, 0.5*size, 0.5*size, 0.1)
    ctx.beginPath()
    for [x,y] in part
      ctx.lineTo x, y
    ctx.stroke()
      
    
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
        drawHyperbola M.smul( 1.0/(radius**2), A), size
        ctx.strokeStyle = "#aaf"
        drawHyperbola M.smul( -1.0/(radius**2), A), size
        
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

  generateAnimation nframes, 1, "animate-rotation-", (step)->
    angle = Math.sin(step / nframes * 2 * Math.PI)
    drawFrame angle

generateAnimation = (nframes, subframes, filePrefix, drawFrame)->
  runUpload = (step)->
    if step is nframes
      console.log "Uploads done for #{filePrefix}"
      return

    for ss in [0...subframes]    
      drawFrame step+(ss/subframes)
      
    uploadToServer "#{filePrefix}#{pad0 4, step}.png", (ajax)->
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

animateLattice = ->
  nframes = 100
  canvas.width = 480
  canvas.height = 240

  scale = 35
  margin = 10
  cellSize = 6
  size = Math.min((canvas.width*0.5) | 0, canvas.height) - margin
  
  drawLattice = (color, latticeMtx)->
    width = size
    height = size

    #take bigger area, it will be clipped
    dx = width * 0.7
    dy = height * 0.7

    #enable clipping
    ctx.beginPath()
    ctx.rect -0.5*width, -0.5*height, width, height
    ctx.clip()
  
    #Combined transformation matrix, from integer lattice to screen
    T = M.smul scale, latticeMtx
    invT = M.inv T

    #quad in the screen coordinates
    quad = [ [-dx, dy], [-dx, -dy], [dx, -dy], [dx, dy]]
    #transform it to the integer lattice
    iquad  = (M.mulv(invT, vi) for vi in quad)
    savedContext ctx, ->
      convexQuadPoints iquad, (ix, iy) ->
        [sx, sy] = M.mulv T, [ix,iy]
        ctx.fillStyle = color
        ctx.beginPath()
        ctx.arc(sx, sy, cellSize, 0, Math.PI*2, true)
        ctx.closePath()
        ctx.fill()
        
      
  hexaLattice = [1,0.5,0,Math.sqrt(0.75)]
      
  drawFrame = (baseColor, mainColor, t)->
    ctx.fillStyle = "#fff"
    ctx.fillRect 0, 0, canvas.width, canvas.height
    
    angle = Math.PI/3*t
    tfm = [Math.cos(angle),-Math.sin(angle),Math.sin(angle), Math.cos(angle)]    
    savedContext ctx, ->
      ctx.translate canvas.width*0.25|0, canvas.height*0.5|0    
      ctx.strokeStyle = "#000"
      ctx.setLineDash [5,5]
      
      drawHyperbola [1/(scale**2),0,0,1/(scale**2)], size
      drawLattice baseColor, hexaLattice
      drawLattice mainColor, M.mul tfm, hexaLattice

      
    #M = [2,1,1,1]
    #A = [2,-1,-1,-2]
    # Vs : (2+-sqrt(5), 1)
    # k: 1/2*(3+sqrt(5))
    minLattice = M.fromColumns M.normalized([2+Math.sqrt(5),1]), M.normalized([2-Math.sqrt(5),1])
    pangle = Math.log(0.5*(3+Math.sqrt(5))) * t
    tfm = [Math.cosh(pangle),Math.sinh(pangle),Math.sinh(pangle), Math.cosh(pangle)]    
    savedContext ctx, ->
      ctx.translate canvas.width*0.75|0, canvas.height*0.5|0    
      ctx.strokeStyle = "#000"
      ctx.setLineDash [5,5]
      drawHyperbola [1/(scale**2),0,0,-1/(scale**2)], size
      drawHyperbola [-1/(scale**2),0,0,1/(scale**2)], size
      
      drawLattice baseColor, minLattice
      drawLattice mainColor, M.mul tfm, minLattice
      

  generateAnimation nframes, 1, "animate-grid-", (step)->
    t = step / nframes
    t = 0.5 - 0.5*Math.cos(t * Math.PI)
    drawFrame "rgba(0,0,255,0.2)", "black", t

animateRotatingPattern = ->
  nframes = 120
  subframes = 5
  rotspeed = 0.5
  nsteps = 4
  scale = 20
  margin = 10
  cellSize = 0.3
  
  canvas.width = 220
  canvas.height = 220

  topplerPattern = parseCellList "3 -3 4;-1 -1 4;0 -1 3;-2 0 4;-1 0 2;0 0 1;1 0 2;2 0 4;0 1 3;1 1 4;-3 3 4"
  rule = new CustomRule """
{
    states: 9,
    foldInitial: null,
    stats: null,

    begin: function(){
	this.stats = {}
    },
    end: function(){
    },
    fold: function(sum, s){
	if(s===0) return sum;
	if(sum==null){
	    sum = new Array(this.states-1);
	    for(var i=0; i!=sum.length; ++i)
		sum[i] = 0;
	}
	sum[s-1] += 1;
	return sum
    },
    map:{
	//first step
	"1 22":1,
	"2 1344": 5,
	"3 244": 6,
	"4 234": 7,
	"4 234": 7,
	"0 14": 8,
	//2nd step
	"1 5588": 1,
	"7 5678":  3,
	
	"7 567": 0,
	"8 17": 2,
	"0 78": 4,

	//remove spurious 4
	"2 13444": 5,
	"1 558888": 1,
	
    },
    next: function(s, sum){
	var sss=""+s+" ";
	if (sum!=null){
	    for(var i=0; i!=sum.length; i++){
		var si = sum[i];
		for(var j=0;j!=si;j++){
		    sss = sss + (i+1);
		}
	    }
	}
	
	if (this.stats.hasOwnProperty(sss)){
	    this.stats[sss] += 1;
	}else{
	    this.stats[sss] = 1;
	}

	if (this.map.hasOwnProperty(sss))
	    return this.map[sss]
	else
	    return 0
	
    }
}"""

  
  M = [2, 1, 1, 1]      
  world = new World M, [[1,0]]
  world.putPattern makeCoord(0,0), topplerPattern
  world.connections = CA.calculateConnections world
  
  view = new View world
  #view.drawCellShape = view.drawCellShapeStar
  view.showStateNumbers = false
  view.showEmpty = true
  view.showConnection = false
  view.setScale scale
  view.setCellSizeRel cellSize
  view.emptyCellColor = '#ccc'
  view.showConnection = true
  
  size = Math.min((canvas.width*0.5) | 0, canvas.height) - margin
  
      
  #initial location
  view.incrementAngle -1.0*world.angle
  
  lastGeneration = 0

  ctx.fillStyle = "#fff" 
  ctx.fillRect 0, 0, canvas.width, canvas.height
  
  generateAnimation nframes, subframes, "animate-toppler-", (step)->
    t = step / nframes
    generation = Math.floor t*nsteps
    
    if generation > lastGeneration
      lastGeneration = generation
      CA.step world, rule
  
    ctx.fillStyle = "rgb(255,255,255,0.1)" 
    ctx.fillRect 0, 0, canvas.width, canvas.height
    
    view.drawGrid canvas, ctx, 20
    view.incrementAngle (world.angle/(nframes*subframes)*nsteps*rotspeed)
    
  
$("#btn-run-rotations").on 'click', -> animateRotations()
$("#btn-run-grid").on 'click', -> animateLattice()
$("#btn-run-logo").on 'click', -> animateRotatingPattern()


