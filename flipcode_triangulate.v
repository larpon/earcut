module earcut

// Ported from https://www.flipcode.com/archives/Efficient_Polygon_Triangulation.shtml

// COTD Entry submitted by John W. Ratcliff [jratcliff@verant.com]

// ** THIS IS A CODE SNIPPET WHICH WILL EFFICIEINTLY TRIANGULATE ANY
// ** POLYGON/CONTOUR (without holes).
// ** SUBMITTED BY JOHN W. RATCLIFF (jratcliff@verant.com) July 22, 2000

const epsilon = 0.0000000001

[direct_array_access; inline]
pub fn tri_area(contour []f32) f32 {
	n := contour.len
	mut a := f32(0.0)

	mut p_x := contour[n - 2]
	mut p_y := contour[n - 1]
	mut q_x := contour[0]
	mut q_y := contour[1]
	for i := 2; i < n - 2; i += 2 {
		a += p_x * q_y - q_x * p_y
		p_x = contour[i + 2]
		p_y = contour[i + 3]
		q_x = contour[i]
		q_y = contour[i + 1]
	}
	return a * 0.5
}

// tri_inside_triangle decides if a point P is inside of the triangle defined by A, B, C.
[inline]
pub fn tri_inside_triangle(a_x f32, a_y f32, b_x f32, b_y f32, c_x f32, c_y f32, p_x f32, p_y f32) bool {
	return ((c_x - b_x) * (p_y - b_y) - (c_y - b_y) * (p_x - b_x)) >= f32(0)
		&& ((a_x - c_x) * (p_y - c_y) - (a_y - c_y) * (p_x - c_x)) >= f32(0)
		&& ((b_x - a_x) * (p_y - a_y) - (b_y - a_y) * (p_x - a_x)) >= f32(0)
	/*
	ax := c_x - b_x
	ay := c_y - b_y
	bx := a_x - c_x
	by := a_y - c_y
	cx := b_x - a_x
	cy := b_y - a_y
	apx := p_x - a_x
	apy := p_y - a_y
	bpx := p_x - b_x
	bpy := p_y - b_y
	cpx := p_x - c_x
	cpy := p_y - c_y

	a_cross_bp := ax*bpy - ay*bpx
	c_cross_ap := cx*apy - cy*apx
	b_cross_cp := bx*cpy - by*cpx

	return ((a_cross_bp >= f32(0)) && (b_cross_cp >= f32(0)) && (c_cross_ap >= f32(0)))
	*/
}

[direct_array_access; inline]
pub fn tri_snip(contour []f32, u int, v int, w int, n int, vi []int) bool {
	a_x := contour[vi[u]]
	a_y := contour[vi[u] + 1]

	b_x := contour[vi[v]]
	b_y := contour[vi[v] + 1]

	c_x := contour[vi[w]]
	c_y := contour[vi[w] + 1]

	if earcut.epsilon > (((b_x - a_x) * (c_y - a_y)) - ((b_y - a_y) * (c_x - a_x))) {
		return false
	}

	mut p_x := f32(0)
	mut p_y := f32(0)
	for p := 0; p < n; p++ {
		if p == u || p == v || p == w {
			continue
		}
		p_x = contour[vi[p]]
		p_y = contour[vi[p] + 1]
		if tri_inside_triangle(a_x, a_y, b_x, b_y, c_x, c_y, p_x, p_y) {
			return false
		}
	}

	return true
}

pub fn tri_process(contour []f32) []int {
	n := contour.len
	assert n > 3 * 2
	assert n % 2 == 0

	// allocate and initialize list of Vertices in polygon
	mut res := []int{len: int(n / 2)}
	mut vi := []int{len: int(n / 2)}

	// we want a counter-clockwise polygon in vi
	if f32(0) < tri_area(contour) {
		for v := 0; v < vi.len; v++ {
			vi[v] = v
		}
	} else {
		for v := 0; v < vi.len; v++ {
			vi[v] = (vi.len - 1) - v
		}
	}

	mut nv := int(n / 2) // n

	// remove nv-2 Vertices, creating 1 triangle every time
	mut count := 2 * nv // error detection

	mut v := nv - 1
	mut m := 0
	for nv > 2 {
		// if we loop, it is probably a non-simple polygon
		count--
		if 0 >= count {
			// Triangulate: ERROR - probable bad polygon!
			panic('bad polygon ${count}')
		}

		// three consecutive vertices in current polygon, <u,v,w>
		mut u := v
		if nv <= u { // previous
			u = 0
		}

		v = u + 1
		if nv <= v { // new v
			v = 0
		}

		mut w := v + 1
		if nv <= w { // next
			w = 0
		}

		if tri_snip(contour, u, v, w, nv, vi) {
			// true names of the vertices
			a := vi[u]
			b := vi[v]
			c := vi[w]

			res << a
			res << b
			res << c
			// output Triangle
			/*
			res << contour[a]
			res << contour[a+1]

			res << contour[b]
			res << contour[b+1]

			res << contour[c]
			res << contour[c+1]*/

			m++

			// remove v from remaining polygon
			mut s := v
			mut t := v + 1
			for t < nv {
				vi[s] = vi[t]
				s++
				t++
				nv--
			}

			// resest error detection counter
			count = 2 * nv
		}
	}
	/*
	unsafe {
		vi.free()
	}*/
	return res
}
