demo.js: src/*.coffee
	browserify -t coffeeify src/demo.coffee > demo.js

test:
	mocha tests/test*.coffee --compilers coffee:coffee-script/register

