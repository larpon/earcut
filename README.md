# earcut

A hand-ported V version of [mapbox/earcut](https://github.com/mapbox/earcut).

The implementation is currently based on commit [ee77dc](https://github.com/mapbox/earcut/tree/ee77dcec3d0f48b38de3976d4cb8819b4bd21aec)

## Example

```v
module main

import earcut

fn main() {
	flat := earcut.flatten(v_logo)
	vertices := flat.vertices
	holes := flat.holes
	indicies := earcut.earcut(vertices, holes, 2)
	println(indicies)
	println(earcut.deviation(vertices, holes, 2, indicies))
}

const (
	v_logo = [[
		[f32(1), 1], [f32(3.5), 1.4],
		[f32(5), 6],
		[f32(6.5), 1.4], [f32(9), 1],
		[f32(6), 9], [f32(4), 9],
	]]
)
```
