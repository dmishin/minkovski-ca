all: application.js

application.js: src/*.coffee
	browserify -t coffeeify src/application.coffee > application.js

test:
	mocha tests/test*.coffee --compilers coffee:coffee-script/register

animations.js: src/*.coffee
	browserify -t coffeeify src/animations.coffee > animations.js


animate-rotation.gif: uploads/animate-rotation-????.png
	echo Making a colormap
	convert +dither -colors 32 -append uploads/animate-rotation-0000.png uploads/animate-rotation-colormap.gif
	echo Convert images to colormap
	mogrify -format gif +dither -map uploads/animate-rotation-colormap.gif uploads/animate-rotation-????.png
	echo Collect GIF
	gifsicle --delay=5 --loopcount=0 -O3 uploads/animate-rotation-????.gif > animate-rotation.gif
	echo Cleanup
	rm uploads/animate-rotation-colormap.gif
	rm uploads/animate-rotation-????.gif


animate-grid.gif: uploads/animate-grid-????.png
	echo Making a colormap
	convert +dither -colors 32 -append uploads/animate-grid-0050.png uploads/animate-grid-colormap.gif
	echo Convert images to colormap
	mogrify -format gif +dither -map uploads/animate-grid-colormap.gif uploads/animate-grid-????.png
	echo Collect GIF
	gifsicle --delay=5 --loopcount=0 -O3 uploads/animate-grid-????.gif > animate-grid.gif
	echo Cleanup
	rm uploads/animate-grid-colormap.gif
	rm uploads/animate-grid-????.gif

publish: test all
	git checkout master
	sh deploy.sh
