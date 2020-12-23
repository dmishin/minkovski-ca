Minkovski Cellular Automata Simulator
=====================================
See it live: https://dmishin.github.io/minkovski-ca/

Theoretical notes
-----------------

Minkovski plane is a 2-dimensional plane, where the role of distance squared is played by the quadratic form

    D = (x1 - x2)^2 - (y1 - y2)^2

Note the minus sign that is the only difference with the usual euclidean distance.

The role of rotation in Minkovski plane is played by *pseudo-rotation* or [squeeze mapping](https://en.wikipedia.org/wiki/Squeeze_mapping): affine transformation that stretches plane *k* times along one diagonal, and compresses it *k* times along the other diagonal. Such pseudo-rotations preserve Minkovski interval between points.

Analog of the unit circle on Minkovski plane is *unit hyperbola*, x^2-y^2=1.

Quite surprisingly, it is possible to find a periodic lattices that are invariant to pseudo-rotations by certain amount. Such lattices are analogs of square and hexagonal euclidean lattices, that are invariant to rotations by 90 and 60 degrees correspondingly.

This program is an attempt to see, what a cellular automata (CAs) defined on such Minkovski lattices look like.

See the [detailed help page](https://dmishin.github.io/minkovski-ca/help.html) for more information on how to use this program.


Building
--------

The program is written in Coffee-script that is compiled to JavaScript. Install it and the required Node modules then run

    $ make



Running
-------

Start local http server, using

    $ make serve

then open http://localhost:8000

Directly opening index.html in the browser would give you limited functionality, because the program uses WebWorkers technology.
