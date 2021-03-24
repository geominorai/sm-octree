# SourceMod Octree

This is a simple Octree implementation in pure SourcePawn.

Function natives are provided in `include/octree.inc`.

## Supported Features

- Point insertion
- Find neighboring points within a radius

## Dependencies

- [SourceMod 1.10](https://www.sourcemod.net/)

## Credits

Octant layout was inspired from https://github.com/jcummings2/pyoctree

Radius lookup was based on the formulation from the paper:
> J. Behley, V. Steinhage, A.B. Cremers. *Efficient Radius Neighbor Search in Three-dimensional Point Clouds*, Proc. of the IEEE International Conference on Robotics and Automation (ICRA), 2015.
