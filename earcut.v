// Copyright(C) 2020 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an ISC license file distributed with this software package
// The following code is a near 1:1 hand-ported V version of https://github.com/mapbox/earcut
// The module can be converted to use f64 precision by a simple /f32/f64/g
module earcut

import math

[inline] [direct_array_access]
pub fn earcut(data []f32, hole_indices []int, rdim int) []i64 {
	dim := if rdim > 0 { rdim } else { 2 }
	has_holes := hole_indices.len > 0
	outer_len := if has_holes { hole_indices[0] * dim } else { data.len }
	mut outer_node := linked_list(data, 0, outer_len, dim, true)
	mut triangles := []i64{}
    if isnil(outer_node) || outer_node.next == outer_node.prev {
		return triangles
	}
	mut min_x := f32(0)
	mut min_y := f32(0)
	mut max_x := f32(0)
	mut max_y := f32(0)
	mut x := f32(0)
	mut y := f32(0)
	mut inv_size := f32(0)
	if has_holes {
		outer_node = eliminate_holes(data, hole_indices, mut outer_node, dim)
	}
	// if the shape is not too simple, we'll use z-order curve hash later; calculate polygon bbox
	if data.len > 80 * dim {
		min_x = data[0]
		max_x = data[0]
		min_y = data[1]
		max_y = data[1]
		for i := dim; i < outer_len; i += dim {
			x = data[i]
			y = data[i + 1]
			if x < min_x { min_x = x }
			if y < min_y { min_y = y }
			if x > max_x { max_x = x }
			if y > max_y { max_y = y }
		}
		// min_x, min_y and inv_size are later used to transform coords into integers for z-order calculation
		inv_size = max_f32(max_x - min_x, max_y - min_y)
		inv_size = if inv_size != 0.0 { 1 / inv_size } else { 0 }
	}
	earcut_linked(mut outer_node, mut triangles, dim, min_x, min_y, inv_size, 0)
	return triangles
}

[inline] [direct_array_access]
// linked_list create a circular doubly linked list from polygon points in the specified winding order
fn linked_list(data []f32, start int, end int, dim int, clockwise bool) &Node {
	mut i := 0
	mut last := &Node(0)

	if clockwise == (signed_area(data, start, end, dim) > 0) {
		for i = start; i < end; i += dim {
			last = insert_node(i, data[i], data[i + 1], mut last)
		}
	} else {
		for i = end - dim; i >= start; i -= dim {
			last = insert_node(i, data[i], data[i + 1], mut last)
		}
	}

	if !isnil(last) && equals(last, last.next) {
		remove_node(mut last)
		last = last.next
	}
	return last
}

[inline]
// filter_points eliminate colinear or duplicate points
fn filter_points(mut start_ &Node, mut end_ &Node) &Node {

	// TODO BUG WORKAROUND
	mut start := &Node(0)
	start = start_

	// TODO BUG WORKAROUND
	mut end := &Node(0)
	end = end_

	if isnil(start) { return start }
	if isnil(end) { end = start }

	mut p := start
	mut again := false
	for {
		again = false
		if !p.steiner && (equals(p, p.next) || area(p.prev, p, p.next) == 0) {
			remove_node(mut p)
			p = p.prev
			end = p.prev
			if p == p.next { break }
			again = true
		} else {
			p = p.next
		}
		if !(again || p != end) { break } //  while (again || p !== end);??
	}

    return end
}

[inline] [direct_array_access]
// earcut_linked main ear slicing loop which triangulates a polygon (given as a linked list)
fn earcut_linked(mut ear_ &Node, mut triangles []i64, dim int, min_x f32, min_y f32, inv_size f32, pass int) {

	// TODO BUG WORKAROUND
	mut ear := &Node(0)
	ear = ear_

	if isnil(ear) { return }
	// interlink polygon nodes in z-order
    if pass == 0 && inv_size > 0.0 {
		index_curve(ear, min_x, min_y, inv_size)
	}

	mut stop := ear
	mut prev := &Node(0)
	mut next := &Node(0)
	mut nil := &Node(0)
	// iterate through ears, slicing them one by one
	for ear.prev != ear.next {
		prev = ear.prev
		next = ear.next
		cutoff := if inv_size > 0 { is_ear_hashed(ear, min_x, min_y, inv_size) } else { is_ear(ear) }
		if cutoff {
			// cut off the triangle
			triangles << prev.i / dim
			triangles << ear.i / dim
			triangles << next.i / dim
			remove_node(mut ear)
			// skipping the next vertex leads to less sliver triangles
			ear = next.next
			stop = next.next
			continue
		}
		ear = next
		// if we looped through the whole remaining polygon and can't find any more ears
		if ear == stop {
			// try filtering points and slicing again
			if pass == 0 {
				mut res := filter_points(mut ear, mut nil)
				earcut_linked(mut res, mut triangles, dim, min_x, min_y, inv_size, 1)
			// if this didn't work, try curing all small self-intersections locally
			} else if pass == 1 {
				mut filtered := filter_points(mut ear, mut nil)
				ear = cure_local_intersections(mut filtered, mut triangles, dim)
				earcut_linked(mut ear, mut triangles, dim, min_x, min_y, inv_size, 2)
			// as a last resort, try splitting the remaining polygon into two
			} else if pass == 2 {
				split_earcut(ear, mut triangles, dim, min_x, min_y, inv_size)
			}
			break
		}
	}
}

[inline]
// is_ear check whether a polygon node forms a valid ear with adjacent nodes
fn is_ear(ear &Node) bool {
	a := ear.prev
	b := ear
	c := ear.next
	if area(a, b, c) >= 0 { return false } // reflex, can't be an ear
	// now make sure we don't have other points inside the potential ear
	mut p := ear.next.next
	for p != ear.prev {
		if point_in_triangle(a.x, a.y, b.x, b.y, c.x, c.y, p.x, p.y) && area(p.prev, p, p.next) >= 0 {
			return false
		}
		p = p.next
	}
	return true
}

[inline]
fn is_ear_hashed(ear &Node, min_x f32, min_y f32, inv_size f32) bool {
	a := ear.prev
	b := ear
	c := ear.next
    if area(a, b, c) >= 0 { return false } // reflex, can't be an ear
    // triangle bbox; min & max are calculated like this for speed
	min_tx := if a.x < b.x { if a.x < c.x { a.x } else { c.x } } else { if b.x < c.x { b.x } else { c.x } }
	min_ty := if a.y < b.y { if a.y < c.y { a.y } else { c.y } } else { if b.y < c.y { b.y } else { c.y } }
	max_tx := if a.x > b.x { if a.x > c.x { a.x } else { c.x } } else { if b.x > c.x { b.x } else { c.x } }
	max_ty := if a.y > b.y { if a.y > c.y { a.y } else { c.y } } else { if b.y > c.y { b.y } else { c.y } }
	// z-order range for the current triangle bbox;
	min_z := z_order(min_tx, min_ty, min_x, min_y, inv_size)
	max_z := z_order(max_tx, max_ty, min_x, min_y, inv_size)
	mut p := ear.prev_z
	mut n := ear.next_z
	// look for points inside the triangle in both directions
	for !isnil(p) && p.z >= min_z && !isnil(n) && n.z <= max_z {
		if p != ear.prev && p != ear.next &&
			point_in_triangle(a.x, a.y, b.x, b.y, c.x, c.y, p.x, p.y) &&
			area(p.prev, p, p.next) >= 0 { return false }
		p = p.prev_z
		if n != ear.prev && n != ear.next &&
			point_in_triangle(a.x, a.y, b.x, b.y, c.x, c.y, n.x, n.y) &&
			area(n.prev, n, n.next) >= 0 { return false }
		n = n.next_z
	}
	// look for remaining points in decreasing z-order
	for !isnil(p) && p.z >= min_z {
		if p != ear.prev && p != ear.next &&
			point_in_triangle(a.x, a.y, b.x, b.y, c.x, c.y, p.x, p.y) &&
			area(p.prev, p, p.next) >= 0 { return false }
		p = p.prev_z
	}
	// look for remaining points in increasing z-order
	for !isnil(n) && n.z <= max_z {
		if n != ear.prev && n != ear.next &&
			point_in_triangle(a.x, a.y, b.x, b.y, c.x, c.y, n.x, n.y) &&
			area(n.prev, n, n.next) >= 0 { return false }
		n = n.next_z
	}
	return true
}

[inline] [direct_array_access]
// cure_local_intersections go through all polygon nodes and cure small local self-intersections
fn cure_local_intersections(mut start_ &Node, mut triangles []i64, dim int) &Node {

	// TODO BUG WORKAROUND
	mut start := &Node(0)
	start = start_


	mut p := start
	mut nil := &Node(0)
	for {
		a := p.prev

		// TODO BUG WORKAROUND
		// b := p.next.next
		mut p_next := p.next
		b := p_next

		if !equals(a, b) && intersects(a, p, p.next, b) && locally_inside(a, b) && locally_inside(b, a) {
			triangles << a.i / dim
			triangles << p.i / dim
			triangles << b.i / dim
			// remove two nodes involved
			remove_node(mut p)
			remove_node(mut p.next)
			p = b
			start = b
		}
		p = p.next
		if p == start { break }
	}
	return filter_points(mut p, mut nil)
}

[inline] [direct_array_access]
// split_earcut try splitting polygon into two and triangulate them independently
fn split_earcut(start &Node, mut triangles []i64, dim int, min_x f32, min_y f32, inv_size f32) {
	// look for a valid diagonal that divides the polygon into two
	mut a := start
	for {
		mut b := a.next.next
		for b != a.prev {
			if a.i != b.i && is_valid_diagonal(a, b) {
				// split the polygon in two by the diagonal
				mut c := split_polygon(mut a, mut b)
				// filter colinear points around the cuts
				a = filter_points(mut a, mut a.next)
				c = filter_points(mut c, mut c.next)
				// run earcut on each half
				earcut_linked(mut a, mut triangles, dim, min_x, min_y, inv_size, 0)
				earcut_linked(mut c, mut triangles, dim, min_x, min_y, inv_size, 0)
				return
			}
			b = b.next
		}
		a = a.next
		if a == start { break }
	}
}

// TODO
fn sort_queue_by_x(a &Node, b &Node) int {
	return int(a.x - b.x)
}

[inline] [direct_array_access]
// eliminate_holes link every hole into the outer loop, producing a single-ring polygon without holes
fn eliminate_holes(data []f32, hole_indices []int, mut outer_node_ &Node, dim int) &Node {

	// TODO BUG WORKAROUND
	mut outer_node := &Node(0)
	outer_node = outer_node_

	mut queue := []&Node{}
	len := hole_indices.len
	mut start := 0
	mut end := 0
	mut list := &Node(0)
	for i := 0; i < len; i++ {
		start = hole_indices[i] * dim
		end = if i < len - 1 { hole_indices[i + 1] * dim } else { data.len }
		list = linked_list(data, start, end, dim, false)
		if list == list.next {
			list.steiner = true
		}
		queue << get_leftmost(list)
	}

	//queue.sort(a.x - b.x) // TODO C error: "error: ';' expected (got "*")"
	//queue.sort(fn(a &Node, b &Node) int { return a.x - b.x })
	queue.sort_with_compare(sort_queue_by_x)

	// process holes from left to right
	list = &Node(0)
	for i := 0; i < queue.len; i++ {
		list = queue[i]
		outer_node = eliminate_hole(mut list, mut outer_node)
		outer_node = filter_points(mut outer_node, mut outer_node.next)
	}
	return outer_node
}

[inline]
// eliminate_hole find a bridge between vertices that connects hole with an outer ring and and link it
fn eliminate_hole(mut hole_ &Node, mut outer_node_ &Node) &Node {

	// TODO BUG WORKAROUND
	mut outer_node := &Node(0)
	outer_node = outer_node_

	// TODO BUG WORKAROUND
	mut hole := &Node(0)
	hole = hole_

	mut bridge := find_hole_bridge(hole, outer_node)
	if isnil(bridge) {
		return outer_node
	}

	mut bridge_reverse := split_polygon(mut bridge, mut hole)

 	// filter collinear points around the cuts
	filtered_bridge := filter_points(mut bridge, mut bridge.next)
	filter_points(mut bridge_reverse, mut bridge_reverse.next)

	// Check if input node was removed by the filtering
	if outer_node == bridge {
		return filtered_bridge
	}
	return outer_node
}

[inline]
// find_hole_bridge David Eberly's algorithm for finding a bridge between hole and outer polygon
fn find_hole_bridge(hole &Node, outer_node &Node) &Node {
	mut p := outer_node
	hx := hole.x
	hy := hole.y
	mut qx := -math.max_f32
	mut m := &Node(0)
	// find a segment intersected by a ray from the hole's leftmost point to the left;
	// segment's endpoint with lesser x will be potential connection point
	mut x := f32(0)
	for {
		if hy <= p.y && hy >= p.next.y && p.next.y != p.y {
			x = p.x + (hy - p.y) * (p.next.x - p.x) / (p.next.y - p.y)
			if x <= hx && x > qx {
				qx = x
				if x == hx {
					if hy == p.y { return p }
					if hy == p.next.y { return p.next }
				}
				m = if p.x < p.next.x { p } else { p.next }
			}
		}
		p = p.next
		if p == outer_node { break } //while (p !== outerNode);
	}
	if isnil(m) { return m }
	if hx == qx { return m } // hole touches outer segment; pick leftmost endpoint
	// look for points inside the triangle of hole point, segment intersection and endpoint;
	// if there are no points found, we have a valid connection;
	// otherwise choose the point of the minimum angle with the ray as connection point
	stop := m
	mx := m.x
	my := m.y
	mut tan_min := math.max_f32
	mut tan := f32(0)
	p = m
	for {
		if hx >= p.x && p.x >= mx && hx != p.x && point_in_triangle(
			if hy < my { f32(hx) } else { f32(qx) },
			hy, mx, my,
			if hy < my { f32(qx) } else { f32(hx) },
			hy, p.x, p.y) {
			tan = f32(math.fabs(hy - p.y) / (hx - p.x)) // tangential
			if locally_inside(p, hole) &&
				(tan < tan_min || (tan == tan_min && (p.x > m.x || (p.x == m.x && sector_contains_sector(m, p))))) {
				m = p
				tan_min = tan
			}
		}
		p = p.next
		if p == stop { break } // while (p !== stop);
	}
	return m
}

[inline]
// sector_contains_sector whether sector in vertex m contains sector in vertex p in the same coordinates
fn sector_contains_sector(m &Node, p &Node) bool {
	return area(m.prev, m, p.prev) < 0 && area(p.next, m, m.next) < 0
}

[inline]
// index_curve interlink polygon nodes in z-order
fn index_curve(start &Node, min_x f32, min_y f32, inv_size f32) {
	mut p := start
	for {
		if p.z == 0 {
			p.z = z_order(p.x, p.y, min_x, min_y, inv_size)
		}
		p.prev_z = p.prev
		p.next_z = p.next
		p = p.next
		if p == start { break }
	}
	p.prev_z.next_z = &Node(0)
	p.prev_z = &Node(0)
	sort_linked(mut p)
}

[inline]
// sort_linked Simon Tatham's linked list merge sort algorithm
// http://www.chiark.greenend.org.uk/~sgtatham/algorithms/listsort.html
fn sort_linked(mut list_ &Node) &Node {

	// TODO BUG WORKAROUND
	mut list := &Node(0)
	list = list_


	mut i := 0
	mut p := &Node(0)
	mut q := &Node(0)
	mut e := &Node(0)
	mut tail := &Node(0)
	mut num_merges := 0
	mut p_size := 0
	mut q_size := 0
	mut in_size := 1
	for {
		p = list
		list = &Node(0)
		tail = &Node(0)
		num_merges = 0
		for !isnil(p) {
			num_merges++
			q = p
			p_size = 0
			for i = 0; i < in_size; i++ {
				p_size++
				q = q.next_z
				if isnil(q) {
					break
				}
			}
			q_size = in_size
			for p_size > 0 || (q_size > 0 && !isnil(q)) {
				if p_size != 0 && (q_size == 0 || isnil(q) || p.z <= q.z) {
					e = p
					p = p.next_z
					p_size--
				} else {
					e = q
					q = q.next_z
					q_size--
				}
				if !isnil(tail) {
					tail.next_z = e
				}
				else {
					list = e
				}
				e.prev_z = tail
				tail = e
			}
			p = q
		}
		tail.next_z = &Node(0)
		in_size *= 2
		if num_merges > 1 { break }
	}
	return list
}

[inline]
// z_order z-order of a point given coords and inverse of the longer side of data bbox
fn z_order(x f32, y f32, min_x f32, min_y f32, inv_size f32) u16 {
	// coords are transformed into non-negative 15-bit integer range
	mut nx := 32767 * u16(x - min_x) * u16(inv_size)
	mut ny := 32767 * u16(y - min_y) * u16(inv_size)

	nx = (nx | (nx << 8)) & 0x00FF00FF
	nx = (nx | (nx << 4)) & 0x0F0F0F0F
	nx = (nx | (nx << 2)) & 0x33333333
	nx = (nx | (nx << 1)) & 0x55555555

	ny = (ny | (ny << 8)) & 0x00FF00FF
	ny = (ny | (ny << 4)) & 0x0F0F0F0F
	ny = (ny | (ny << 2)) & 0x33333333
	ny = (ny | (ny << 1)) & 0x55555555

	return nx | (ny << 1)
}

[inline]
// get_leftmost find the leftmost node of a polygon ring
fn get_leftmost(start &Node) &Node {
	mut p := start
	mut leftmost := start
	for {
		if p.x < leftmost.x || (p.x == leftmost.x && p.y < leftmost.y) {
			leftmost = p
		}
		p = p.next
		if p == start { break }
	}
	return leftmost
}

[inline]
// point_in_triangle check if a point lies within a convex triangle
fn point_in_triangle(ax f32, ay f32, bx f32, by f32, cx f32, cy f32, px f32, py f32) bool {
	return (cx - px) * (ay - py) - (ax - px) * (cy - py) >= 0 &&
		(ax - px) * (by - py) - (bx - px) * (ay - py) >= 0 &&
		(bx - px) * (cy - py) - (cx - px) * (by - py) >= 0
}

[inline]
// is_valid_diagonal check if a diagonal between two polygon nodes is valid (lies in polygon interior)
fn is_valid_diagonal(a &Node, b &Node) bool {
	doesnt_intersect := a.next.i != b.i && a.prev.i != b.i && !intersects_polygon(a, b) // dones't intersect other edges
	locally_visible := locally_inside(a, b) && locally_inside(b, a) && middle_inside(a, b) // locally visible
	not_opposite_facing := (area(a.prev, a, b.prev) != 0.0 || area(a, b.prev, b) != 0.0) // does not create opposite-facing sectors
	zero_length_case := equals(a, b) && area(a.prev, a, a.next) > 0 && area(b.prev, b, b.next) > 0 // special zero-length case
	return doesnt_intersect && ((locally_visible && not_opposite_facing) || zero_length_case)
}

[inline]
// area signed area of a triangle
fn area(p &Node, q &Node, r &Node) f32 {
	return (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y)
}

[inline]
// equals check if two points are equal
fn equals(p1 &Node, p2 &Node) bool {
	return p1.x == p2.x && p1.y == p2.y
}

[inline]
// intersects check if two segments intersect
fn intersects(p1 &Node, q1 &Node, p2 &Node, q2 &Node) bool {
	o1 := sign(area(p1, q1, p2))
    o2 := sign(area(p1, q1, q2))
    o3 := sign(area(p2, q2, p1))
    o4 := sign(area(p2, q2, q1))
    if o1 != o2 && o3 != o4 { return true } // general case
    if o1 == 0 && on_segment(p1, p2, q1) { return true } // p1, q1 and p2 are collinear and p2 lies on p1q1
    if o2 == 0 && on_segment(p1, q2, q1) { return true } // p1, q1 and q2 are collinear and q2 lies on p1q1
    if o3 == 0 && on_segment(p2, p1, q2) { return true } // p2, q2 and p1 are collinear and p1 lies on p2q2
    if o4 == 0 && on_segment(p2, q1, q2) { return true } // p2, q2 and q1 are collinear and q1 lies on p2q2
    return false
}

[inline]
// on_segment for collinear points p, q, r, check if point q lies on segment pr
fn on_segment(p &Node, q &Node, r &Node) bool {
	return q.x <= max_f32(p.x, r.x) && q.x >= min_f32(p.x, r.x) && q.y <= max_f32(p.y, r.y) && q.y >= min_f32(p.y, r.y)
}

[inline]
fn max_f32(a f32, b f32) f32 {
	if a > b {
		return a
	}
	return b
}

[inline]
fn min_f32(a f32, b f32) f32 {
	if a < b {
		return a
	}
	return b
}

[inline]
fn sign(num f32) int {
	if num > 0 {
		return 1
	} else if num < 0 {
		return -1
	}
	return 0
}

[inline]
// intersects_polygon check if a polygon diagonal intersects any polygon segments
fn intersects_polygon(a &Node, b &Node) bool {
	//mut p := &Node(0)
	mut p := a
	for {
		if p.i != a.i && p.next.i != a.i && p.i != b.i && p.next.i != b.i && intersects(p, p.next, a, b) {
			return true
		}
		p = p.next
		if p == a { break }
	}
	return false
}

[inline]
// locally_inside check if a polygon diagonal is locally inside the polygon
fn locally_inside(a &Node, b &Node) bool {
	if area(a.prev, a, a.next) < 0 {
		return area(a, b, a.next) >= 0 && area(a, a.prev, b) >= 0
	} else {
		return area(a, b, a.prev) < 0 || area(a, a.next, b) < 0
	}
}

[inline]
// middle_inside check if the middle point of a polygon diagonal is inside the polygon
fn middle_inside(a &Node, b &Node) bool {
	mut p := a
	//mut p := &Node(0)
	mut inside := false
	px := (a.x + b.x) / 2
	py := (a.y + b.y) / 2

	for {
		if ((p.y > py) != (p.next.y > py)) && p.next.y != p.y && (px < (p.next.x - p.x) * (py - p.y) / (p.next.y - p.y) + p.x) {
            inside = !inside
		}
		p = p.next
		if p == a { break }
	}
    return inside
}

[inline]
// split_polygon link two polygon vertices with a bridge; if the vertices belong to the same ring, it splits polygon into two;
// if one belongs to the outer ring and another to a hole, it merges it into a single ring
fn split_polygon(mut a &Node, mut b &Node) &Node {
	mut a2 := &Node{
		i: a.i
		x: a.x
		y: a.y
	}
	mut b2 := &Node{
		i: b.i
		x: b.x
		y: b.y
	}
	mut an := a.next
	mut bp := b.prev
	a.next = b
	b.prev = a
	//
	a2.next = an
	an.prev = a2
	//
	b2.next = a2
	a2.prev = b2
	//
	bp.next = b2
	b2.prev = bp
	return b2
}

[inline]
// insert_node create a node and optionally link it with previous one (in a circular doubly linked list)
fn insert_node(i i64, x f32, y f32, mut last &Node) &Node {
	mut p := &Node{
		i: i
		x: x
		y: y
	}
	if isnil(last) {
		p.prev = p
		p.next = p
	} else {
		p.next = last.next
		p.prev = last
		last.next.prev = p
		last.next = p
	}
	return p
}

[inline]
fn remove_node(mut p &Node) {
	p.next.prev = p.prev
	p.prev.next = p.next
	if !isnil(p.prev_z) { p.prev_z.next_z = p.next_z }
	if !isnil(p.next_z) { p.next_z.prev_z = p.prev_z }
	//TODO unsafe { free(p) }
}

[heap]
pub struct Node {
mut:
	// vertex index in coordinates array
	i		i64
	// vertex coordinates
	x		f32
	y		f32
	// previous and next vertex nodes in a polygon ring
	prev	&Node = 0
	next	&Node = 0
	// z-order curve value
	z		f32
	// previous and next nodes in z-order
	prev_z	&Node = 0
	next_z	&Node = 0
	// indicates whether this is a steiner point
    steiner	bool
}

fn (n &Node) str() string {
    return '&Node@${ptr_str(n)} {
        i: $n.i,
        x: $n.x,
        y: $n.y,
        z: $n.z,
        prev: *${ptr_str(n.prev)},
        next: *${ptr_str(n.next)},
        prev_z: *${ptr_str(n.prev_z)},
        next_z: *${ptr_str(n.prev_z)}
        steiner: $n.steiner
}'
}

[inline] [direct_array_access]
// deviation return a percentage difference between the polygon area and its triangulation area;
// used to verify correctness of triangulation
pub fn deviation(data []f32, hole_indices []int, dim int, triangles []i64) f32 {
	has_holes := hole_indices.len > 0
	outer_len := if has_holes { hole_indices[0] * dim } else { data.len }
	mut polygon_area := f32(math.fabs(signed_area(data, 0, outer_len, dim)))
	if has_holes {
		mut i := 0
		len := hole_indices.len
		mut start := hole_indices[0] * dim
		mut end := if i < len - 1 { hole_indices[i + 1] * dim } else { data.len }
		for ; i < len; i++ {
			start = hole_indices[i] * dim
			end = if i < len - 1 { hole_indices[i + 1] * dim } else { data.len }
			polygon_area -= f32(math.fabs(signed_area(data, start, end, dim)))
		}
	}
	mut triangles_area := f32(0)
	for i := 0; i < triangles.len; i += 3 {
		a := i64(triangles[i] * dim)
		b := i64(triangles[i + 1] * dim)
		c := i64(triangles[i + 2] * dim)
		triangles_area += f32(math.abs(
			(data[a] - data[c]) * (data[b + 1] - data[a + 1]) -
			(data[a] - data[b]) * (data[c + 1] - data[a + 1])))
	}
	if polygon_area == 0 && triangles_area == 0 {
		return 0
	} else {
		return f32(math.fabs((triangles_area - polygon_area) / polygon_area))
	}
}

[inline] [direct_array_access]
fn signed_area(data []f32, start int, end int, dim int) f32 {
	mut sum := f32(0)
	mut j := end - dim
	mut i := start
	for ; i < end; i += dim {
		sum += (data[j] - data[i]) * (data[i + 1] + data[j + 1])
		j = i
	}
	return sum
}

pub struct FlatResult {
pub:
	dimensions	int
pub mut:
	vertices	[]f32
	holes		[]int
}
[inline] [direct_array_access]
// flatten turn a polygon in a multi-dimensional array form (e.g. as in GeoJSON) into a form Earcut accepts
pub fn flatten(data [][][]f32) FlatResult {
	dim := data[0][0].len
	mut result := FlatResult{ dimensions: dim }
	mut hole_index := 0
	for i := 0; i < data.len; i++ {
		for j := 0; j < data[i].len; j++ {
			for d := 0; d < dim; d++ {
				result.vertices << data[i][j][d]
			}
		}
		if i > 0 {
			hole_index += data[i - 1].len
			result.holes << hole_index
		}
	}
	return result
}
