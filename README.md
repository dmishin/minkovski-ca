Minkovski Cellular Automata Simulator
=====================================
See it live: https://dmishin.github.io/minkovski-ca/

Theoretical notes
-----------------

Minkovski plane, here, is a 2-dimensional plane, where the role of distance squared plays quadratic form:

    D = (x1 - x2)^2 - (y1 - y2)^2

Note the minus sign that is the only difference with the usual euclidean distance.


Analog of unit circle on Minkovski plane is *unit hyperbola*, x^2-y^2=1.

The role of rotations play *pseudo-rotations*: affine transforms that stretch plane *k* times along one axis, and compress it k times along the other axis. Such pseudo-rotations preserve Minkovski interval between points.

Quite surprisingly, it is possible to find a periodic lattices that are invariant to pseudo-rotations by certain amount. Such lattices are analogs of square and hexagonal euclidean lattices, that are invariant to rotations by 90 and 60 degrees correspondingly.

This program is an attempt to see, what a cellular automata (CAs) defined on such Minkovski lattices look like.


Building
--------

The program is written in Coffee-script.
Install required Node modules then run

    $ make

Running
-------

Open demo.html in any recent browser.
