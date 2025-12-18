// Copyright(C) 2020-2022 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by MIT and ISC licenses (mapbox).
// Both files are distributed with this software package.
module main

import gg
import earcut

const win_width = 550
const win_height = 450
const move_by_pix = 4

struct App {
mut:
	gg           &gg.Context
	pos          Point
	dude         Polygon
	v_logo       Polygon
	v_logo_light Polygon
	rect         Polygon
}

fn (mut app App) on_key_down(key gg.KeyCode) {
	match key {
		.w, .up {
			app.pos.y -= move_by_pix
		}
		.a, .left {
			app.pos.x -= move_by_pix
		}
		.s, .down {
			app.pos.y += move_by_pix
		}
		.d, .right {
			app.pos.x += move_by_pix
		}
		else {}
	}
}

struct Point {
mut:
	x f32
	y f32
}

struct Polygon {
mut:
	points []f32
	holes  []int
}

fn main() {
	mut app := &App{
		gg:  unsafe { nil }
		pos: Point{50, 50}
	}
	app.gg = gg.new_context(
		bg_color:      gg.black
		width:         win_width
		height:        win_height
		create_window: true
		window_title:  'Polygon'
		frame_fn:      frame
		event_fn:      event
		user_data:     app
		init_fn:       init
	)
	app.gg.run()
}

fn init(mut app App) {
	flat_dude := earcut.flatten(dude)
	app.dude.points = flat_dude.vertices
	app.dude.holes = flat_dude.holes
	add(mut app.dude.points, -150, -350)

	flat_v := earcut.flatten(v_logo)
	app.v_logo.points = flat_v.vertices
	app.v_logo.holes = flat_v.holes
	multiply(mut app.v_logo.points, 20, 20)
	add(mut app.v_logo.points, -10, -20)

	flat_v_light := earcut.flatten(v_logo_light)
	app.v_logo_light.points = flat_v_light.vertices
	app.v_logo_light.holes = flat_v_light.holes
	multiply(mut app.v_logo_light.points, 20, 20)
	add(mut app.v_logo_light.points, -10, -20)

	flat_rect := earcut.flatten(rect)
	app.rect.points = flat_rect.vertices
	app.rect.holes = flat_rect.holes
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

fn event(e &gg.Event, mut app App) {
	match e.typ {
		.key_down {
			app.on_key_down(e.key_code)
		}
		else {}
	}
}

fn frame(app &App) {
	app.gg.begin()
	app.draw()
	app.gg.end()
}

@[direct_array_access]
fn (app &App) draw() {
	dim := 2
	mut pts := unsafe { app.dude.points }
	mut holes := unsafe { app.dude.holes }
	mut indicies := earcut.earcut(pts, holes, dim)
	for i := 0; i < indicies.len; i += 3 {
		p1x := app.pos.x + f32(pts[int(indicies[i] * dim)])
		p1y := app.pos.y + f32(pts[int(indicies[i] * dim + 1)])

		p2x := app.pos.x + f32(pts[int(indicies[i + 1] * dim)])
		p2y := app.pos.y + f32(pts[int(indicies[i + 1] * dim + 1)])

		p3x := app.pos.x + f32(pts[int(indicies[i + 2] * dim)])
		p3y := app.pos.y + f32(pts[int(indicies[i + 2] * dim + 1)])

		app.gg.draw_triangle_filled(f32(p1x), f32(p1y), f32(p2x), f32(p2y), f32(p3x),
			f32(p3y), gg.orange)
	}
	for i := 0; i < pts.len; i += 2 {
		app.gg.draw_rect_filled(f32(app.pos.x + f32(pts[i]) - 2), f32(app.pos.y + f32(pts[i + 1]) - 2),
			4, 4, gg.blue)
	}

	pts = unsafe { app.v_logo.points }
	holes = unsafe { app.v_logo.holes }
	indicies = earcut.earcut(pts, holes, dim)
	for i := 0; i < indicies.len; i += 3 {
		p1x := app.pos.x + f32(pts[int(indicies[i] * dim)])
		p1y := app.pos.y + f32(pts[int(indicies[i] * dim + 1)])

		p2x := app.pos.x + f32(pts[int(indicies[i + 1] * dim)])
		p2y := app.pos.y + f32(pts[int(indicies[i + 1] * dim + 1)])

		p3x := app.pos.x + f32(pts[int(indicies[i + 2] * dim)])
		p3y := app.pos.y + f32(pts[int(indicies[i + 2] * dim + 1)])

		app.gg.draw_triangle_filled(f32(p1x), f32(p1y), f32(p2x), f32(p2y), f32(p3x),
			f32(p3y), gg.rgb(64, 95, 134))
	}

	pts = unsafe { app.v_logo_light.points }
	holes = unsafe { app.v_logo_light.holes }
	indicies = earcut.earcut(pts, holes, dim)
	for i := 0; i < indicies.len; i += 3 {
		p1x := app.pos.x + f32(pts[int(indicies[i] * dim)])
		p1y := app.pos.y + f32(pts[int(indicies[i] * dim + 1)])

		p2x := app.pos.x + f32(pts[int(indicies[i + 1] * dim)])
		p2y := app.pos.y + f32(pts[int(indicies[i + 1] * dim + 1)])

		p3x := app.pos.x + f32(pts[int(indicies[i + 2] * dim)])
		p3y := app.pos.y + f32(pts[int(indicies[i + 2] * dim + 1)])

		app.gg.draw_triangle_filled(f32(p1x), f32(p1y), f32(p2x), f32(p2y), f32(p3x),
			f32(p3y), gg.rgb(93, 136, 193))
	}

	pts = unsafe { app.rect.points }
	holes = unsafe { app.rect.holes }
	indicies = earcut.earcut(pts, holes, dim)
	for i := 0; i < indicies.len; i += 3 {
		p1x := app.pos.x + f32(pts[int(indicies[i] * dim)])
		p1y := app.pos.y + f32(pts[int(indicies[i] * dim + 1)])

		p2x := app.pos.x + f32(pts[int(indicies[i + 1] * dim)])
		p2y := app.pos.y + f32(pts[int(indicies[i + 1] * dim + 1)])

		p3x := app.pos.x + f32(pts[int(indicies[i + 2] * dim)])
		p3y := app.pos.y + f32(pts[int(indicies[i + 2] * dim + 1)])

		app.gg.draw_triangle_filled(f32(p1x), f32(p1y), f32(p2x), f32(p2y), f32(p3x),
			f32(p3y), gg.rgb(64, 45, 114))
	}
	for i := 0; i < pts.len; i += 2 {
		app.gg.draw_rect_filled(f32(app.pos.x + f32(pts[i]) - 2), f32(app.pos.y + f32(pts[i + 1]) - 2),
			4, 4, gg.blue)
	}
}

const dude = [
	[
		[f32(280.35714), 648.79075],
		[f32(286.78571), 662.8979],
		[f32(263.28607), 661.17871],
		[f32(262.31092), 671.41548],
		[f32(250.53571), 677.00504],
		[f32(250.53571), 683.43361],
		[f32(256.42857), 685.21933],
		[f32(297.14286), 669.50504],
		[f32(289.28571), 649.50504],
		[f32(285), 631.6479],
		[f32(285), 608.79075],
		[f32(292.85714), 585.21932],
		[f32(306.42857), 563.79075],
		[f32(323.57143), 548.79075],
		[f32(339.28571), 545.21932],
		[f32(357.85714), 547.36218],
		[f32(375), 550.21932],
		[f32(391.42857), 568.07647],
		[f32(404.28571), 588.79075],
		[f32(413.57143), 612.36218],
		[f32(417.14286), 628.07647],
		[f32(438.57143), 619.1479],
		[f32(438.03572), 618.96932],
		[f32(437.5), 609.50504],
		[f32(426.96429), 609.86218],
		[f32(424.64286), 615.57647],
		[f32(419.82143), 615.04075],
		[f32(420.35714), 605.04075],
		[f32(428.39286), 598.43361],
		[f32(437.85714), 599.68361],
		[f32(443.57143), 613.79075],
		[f32(450.71429), 610.21933],
		[f32(431.42857), 575.21932],
		[f32(405.71429), 550.21932],
		[f32(372.85714), 534.50504],
		[f32(349.28571), 531.6479],
		[f32(346.42857), 521.6479],
		[f32(346.42857), 511.6479],
		[f32(350.71429), 496.6479],
		[f32(367.85714), 476.6479],
		[f32(377.14286), 460.93361],
		[f32(385.71429), 445.21932],
		[f32(388.57143), 404.50504],
		[f32(360), 352.36218],
		[f32(337.14286), 325.93361],
		[f32(330.71429), 334.50504],
		[f32(347.14286), 354.50504],
		[f32(337.85714), 370.21932],
		[f32(333.57143), 359.50504],
		[f32(319.28571), 353.07647],
		[f32(312.85714), 366.6479],
		[f32(350.71429), 387.36218],
		[f32(368.57143), 408.07647],
		[f32(375.71429), 431.6479],
		[f32(372.14286), 454.50504],
		[f32(366.42857), 462.36218],
		[f32(352.85714), 462.36218],
		[f32(336.42857), 456.6479],
		[f32(332.85714), 438.79075],
		[f32(338.57143), 423.79075],
		[f32(338.57143), 411.6479],
		[f32(327.85714), 405.93361],
		[f32(320.71429), 407.36218],
		[f32(315.71429), 423.07647],
		[f32(314.28571), 440.21932],
		[f32(325), 447.71932],
		[f32(324.82143), 460.93361],
		[f32(317.85714), 470.57647],
		[f32(304.28571), 483.79075],
		[f32(287.14286), 491.29075],
		[f32(263.03571), 498.61218],
		[f32(251.60714), 503.07647],
		[f32(251.25), 533.61218],
		[f32(260.71429), 533.61218],
		[f32(272.85714), 528.43361],
		[f32(286.07143), 518.61218],
		[f32(297.32143), 508.25504],
		[f32(297.85714), 507.36218],
		[f32(298.39286), 506.46932],
		[f32(307.14286), 496.6479],
		[f32(312.67857), 491.6479],
		[f32(317.32143), 503.07647],
		[f32(322.5), 514.1479],
		[f32(325.53571), 521.11218],
		[f32(327.14286), 525.75504],
		[f32(326.96429), 535.04075],
		[f32(311.78571), 540.04075],
		[f32(291.07143), 552.71932],
		[f32(274.82143), 568.43361],
		[f32(259.10714), 592.8979],
		[f32(254.28571), 604.50504],
		[f32(251.07143), 621.11218],
		[f32(250.53571), 649.1479],
		[f32(268.1955), 654.36208],
	],
	[
		[f32(325), 437],
		[f32(320), 423],
		[f32(329), 413],
		[f32(332), 423],
	],
	[
		[f32(320.72342), 480],
		[f32(338.90617), 465.96863],
		[f32(347.99754), 480.61584],
		[f32(329.8148), 510.41534],
		[f32(339.91632), 480.11077],
		[f32(334.86556), 478.09046],
	],
]

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

const rect = [
	[
		[f32(400), 50],
		[f32(490), 60],
		[f32(500), 150],
		[f32(380), 140],
	],
	[
		[f32(420), 70], // BUG at x=400 it works??
		[f32(470), 80],
		[f32(460), 120],
		[f32(400), 110],
	],
]
