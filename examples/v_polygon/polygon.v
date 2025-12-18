// Copyright(C) 2020-2022 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by MIT and ISC licenses (mapbox).
// Both files are distributed with this software package.
module main

import gg
import earcut

const win_width = 550
const win_height = 450

struct App {
mut:
	gg           &gg.Context
	v_logo       Polygon
	v_logo_light Polygon
}

struct Polygon {
mut:
	points []f32
	holes  []int
}

fn main() {
	mut app := &App{
		gg: unsafe { nil }
	}
	app.gg = gg.new_context(
		bg_color:      gg.black
		width:         win_width
		height:        win_height
		create_window: true
		window_title:  'Polygon'
		frame_fn:      frame
		user_data:     app
		init_fn:       init
	)
	app.gg.run()
}

fn init(mut app App) {
	flat_v := earcut.flatten(v_logo)
	app.v_logo.points = flat_v.vertices
	app.v_logo.holes = flat_v.holes
	multiply(mut app.v_logo.points, 20, 20)
	add(mut app.v_logo.points, 170, 110)
	//
	flat_v_light := earcut.flatten(v_logo_light)
	app.v_logo_light.points = flat_v_light.vertices
	app.v_logo_light.holes = flat_v_light.holes
	multiply(mut app.v_logo_light.points, 20, 20)
	add(mut app.v_logo_light.points, 170, 110)
}

fn add(mut vertices []f32, x f32, y f32) {
	for i := 0; i < vertices.len; i += 2 {
		vertices[i] += x
		vertices[i + 1] += y
	}
}

fn multiply(mut vertices []f32, x f32, y f32) {
	for i := 0; i < vertices.len; i += 2 {
		vertices[i] *= x
		vertices[i + 1] *= y
	}
}

fn frame(app &App) {
	app.gg.begin()
	app.draw()
	app.gg.end()
}

@[direct_array_access; inline]
fn (app &App) draw() {
	dim := 2
	mut pts := unsafe { app.v_logo.points }
	mut holes := unsafe { app.v_logo.holes }
	mut indicies := earcut.earcut(pts, holes, dim)
	// w050 := f32(app.gg.width)*0.5
	// h050 := f32(app.gg.height)*0.5
	for i := 0; i < indicies.len; i += 3 {
		p1x := f32(pts[int(indicies[i] * dim)])
		p1y := f32(pts[int(indicies[i] * dim + 1)])

		p2x := f32(pts[int(indicies[i + 1] * dim)])
		p2y := f32(pts[int(indicies[i + 1] * dim + 1)])

		p3x := f32(pts[int(indicies[i + 2] * dim)])
		p3y := f32(pts[int(indicies[i + 2] * dim + 1)])

		app.gg.draw_triangle_filled(f32(p1x), f32(p1y), f32(p2x), f32(p2y), f32(p3x),
			f32(p3y), gg.rgb(64, 95, 134))
	}

	pts = unsafe { app.v_logo_light.points }
	holes = unsafe { app.v_logo_light.holes }
	indicies = earcut.earcut(pts, holes, dim)
	for i := 0; i < indicies.len; i += 3 {
		p1x := f32(pts[int(indicies[i] * dim)])
		p1y := f32(pts[int(indicies[i] * dim + 1)])

		p2x := f32(pts[int(indicies[i + 1] * dim)])
		p2y := f32(pts[int(indicies[i + 1] * dim + 1)])

		p3x := f32(pts[int(indicies[i + 2] * dim)])
		p3y := f32(pts[int(indicies[i + 2] * dim + 1)])

		app.gg.draw_triangle_filled(f32(p1x), f32(p1y), f32(p2x), f32(p2y), f32(p3x),
			f32(p3y), gg.rgb(93, 136, 193))
	}
}

const v_logo = [
	[
		[f32(1), 1],
		[f32(3.5), 1.4],
		[f32(5), 6],
		[f32(6.5), 1.4],
		[f32(9), 1],
		[f32(6), 9],
		[f32(4), 9],
	],
]
const v_logo_light = [
	[
		[f32(1), 1],
		[f32(3.5), 1.4],
		[f32(6), 9],
		[f32(4), 9],
	],
]
