
-- cairo graphics library ffi binding.
-- Written by Cosmin Apreutesei. Public Domain.

-- Supports garbage collection, metatype methods, accepting and returning
-- strings, returning multiple values instead of passing output buffers,
-- and API additions for completeness (drawing quad curves, getting and
-- setting pixel values, etc.). Note that methods from specific backends and
-- extensions are not added and cannot be added after loading this module
-- due to limitations of ffi.metatype(). An exception is made for the pixman
-- backend because it's a required dependency on all platforms.
-- Still looking for a nice way to solve this.

local ffi = require'ffi'
require'cairo_h'
local C = ffi.load'cairo'
local M = {C = C}

local function sym(name) return C[name] end
local function _C(name) --return C[name] only if it exists
    return pcall(sym, name) and C[name] or nil
end

setmetatable(M, {__index = function(t, k, v)
	--lookup C.cairo_<symbol> or C.CAIRO_<SYMBOL>, populate M with it and return it
	local sym = _C((k:upper() == k and 'CAIRO_' or 'cairo_')..k) or C[k]
	rawset(t, k, sym)
	return sym
end})

--private functions, only available in our custom build
M.font_options_set_lcd_filter = _C'_cairo_font_options_set_lcd_filter'
M.font_options_get_lcd_filter = _C'_cairo_font_options_get_lcd_filter'
M.font_options_set_round_glyph_positions = _C'_cairo_font_options_set_round_glyph_positions'
M.font_options_get_round_glyph_positions = _C'_cairo_font_options_get_round_glyph_positions'

local function X(prefix, value)
	return type(value) == 'string' and C[prefix..value:upper()] or value
end

-- garbage collector / ref'counting integration
-- NOTE: free() and destroy() do not return a value to enable the idiom
-- self.obj = self.obj:free().

local function free_ref_counted(o)
	local n = o:get_reference_count() - 1
	o:destroy()
	if n ~= 0  then
		error(string.format('refcount of %s is %d, should be 0', tostring(o), n))
	end
end

function M.destroy(cr)
	ffi.gc(cr, nil)
	C.cairo_destroy(cr)
end

function M.surface_destroy(surface)
	ffi.gc(surface, nil)
	C.cairo_surface_destroy(surface)
end

function M.device_destroy(device)
	ffi.gc(device, nil)
	C.cairo_device_destroy(device)
end

function M.pattern_destroy(pattern)
	ffi.gc(pattern, nil)
	C.cairo_pattern_destroy(pattern)
end

function M.scaled_font_destroy(font)
	ffi.gc(font, nil)
	C.cairo_scaled_font_destroy(font)
end

function M.font_face_destroy(ff)
	ffi.gc(ff, nil)
	C.cairo_font_face_destroy(ff)
end

function M.font_options_destroy(ff)
	ffi.gc(ff, nil)
	C.cairo_font_options_destroy(ff)
end

function M.region_destroy(region)
	ffi.gc(region, nil)
	C.cairo_region_destroy(region)
end

function M.path_destroy(path)
	ffi.gc(path, nil)
	C.cairo_path_destroy(path)
end

function M.rectangle_list_destroy(rl)
	ffi.gc(rl, nil)
	C.cairo_rectangle_list_destroy(rl)
end

function M.glyph_free(c)
	ffi.gc(c, nil)
	C.cairo_glyph_free(c)
end

function M.text_cluster_free(c)
	ffi.gc(c, nil)
	C.cairo_text_cluster_free(c)
end

function M.create(...)
	return ffi.gc(C.cairo_create(...), M.destroy)
end

function M.reference(...)
	return ffi.gc(C.cairo_reference(...), M.destroy)
end

M.get_reference_count = C.cairo_get_reference_count

function M.pop_group(...)
	return ffi.gc(C.cairo_pop_group(...), M.pattern_destroy)
end

local function check_surface(surface)
	assert(surface:status() == C.CAIRO_STATUS_SUCCESS, surface:status_string())
	return surface
end

function M.surface_create_similar(surface, content, w, h)
	return ffi.gc(check_surface(
			C.cairo_surface_create_similar(surface, X('CAIRO_CONTENT_', content), w, h)
		), M.surface_destroy)
end

function M.surface_create_similar_image(surface, format, w, h)
	return ffi.gc(check_surface(
			C.cairo_surface_create_similar_image(surface, X('CAIRO_FORMAT_', format), w, h)
		), M.surface_destroy)
end

function M.surface_create_for_rectangle(...)
	return ffi.gc(check_surface(C.cairo_surface_create_for_rectangle(...)), M.surface_destroy)
end

function M.surface_create_for_data(...)
	return ffi.gc(check_surface(C.cairo_surface_create_for_data(...)), M.surface_destroy)
end

function M.surface_create_observer(mode)
	return ffi.gc(check_surface(C.cairo_surface_create_observer(X('CAIRO_SURFACE_OBSERVER_', mode))), M.surface_destroy)
end

function M.surface_reference(...)
	return ffi.gc(C.cairo_surface_reference(...), M.surface_destroy)
end

local cairo_formats = {
	bgra8  = C.CAIRO_FORMAT_ARGB32,
	bgrx8  = C.CAIRO_FORMAT_RGB24,
	g8     = C.CAIRO_FORMAT_A8,
	g1     = C.CAIRO_FORMAT_A1,
	rgb565 = C.CAIRO_FORMAT_RGB16_565,
}
function M.image_surface_create(fmt, w, h)
	if type(fmt) == 'table' then
		local bmp = fmt
		local format = assert(cairo_formats[bmp.format], 'unsupported format')
		return ffi.gc(check_surface(
				C.cairo_image_surface_create_for_data(bmp.data, format, bmp.w, bmp.h, bmp.stride)
			), M.surface_destroy)
	else
		return ffi.gc(check_surface(C.cairo_image_surface_create(fmt, w, h)), M.surface_destroy)
	end
end

function M.image_surface_create_from_png(...)
	return ffi.gc(check_surface(C.cairo_image_surface_create_from_png(...)), M.surface_destroy)
end

function M.image_surface_create_from_png_stream(...)
	return ffi.gc(check_surface(C.cairo_image_surface_create_from_png_stream(...)), M.surface_destroy)
end

local r = ffi.new'cairo_rectangle_t'
function M.recording_surface_create(content, x, y, w, h)
	if x then
		r.x = x
		r.y = y
		r.width = w
		r.height = h
	end
	return ffi.gc(check_surface(
		C.cairo_recording_surface_create(
			X('CAIRO_CONTENT_', content),
			x and r or nil)
		), M.surface_destroy)
end

local r = ffi.new'cairo_rectangle_t'
local function extents_function(f)
	return function(sr)
		f(sr, r)
		return r.x, r.y, r.width, r.height
	end
end
M.recording_surface_get_extents = extents_function(C.cairo_recording_surface_get_extents)

local extents = ffi.new'cairo_rectangle_int_t[1]'
function M.surface_map_to_image(sr, x, y, w, h)
	if x1 then
		extents.x = x
		extents.y = y
		extents.w = w
		extents.h = h
	end
	local image = check_surface(C.cairo_surface_map_to_image(sr, x1 and extents or nil))
	return ffi.gc(image, function()
		C.cairo_surface_unmap_image(sr, image)
	end)
end

function M.surface_unmap_image(sr, image)
	ffi.gc(image, nil)
	C.cairo_surface_unmap_image(sr, image)
end

function M.device_reference(...)
	return ffi.gc(C.cairo_device_reference(...), M.device_destroy)
end

function M.pattern_create_raster_source(data, content, w, h)
	return ffi.gc(C.cairo_pattern_create_raster_source(data, X('CAIRO_CONTENT_', content), w, h), M.pattern_destroy)
end

function M.pattern_create_rgb(...)
	return ffi.gc(C.cairo_pattern_create_rgb(...), M.pattern_destroy)
end

function M.pattern_create_rgba(...)
	return ffi.gc(C.cairo_pattern_create_rgba(...), M.pattern_destroy)
end

function M.pattern_create_for_surface(...)
	return ffi.gc(C.cairo_pattern_create_for_surface(...), M.pattern_destroy)
end

function M.pattern_create_linear(...)
	return ffi.gc(C.cairo_pattern_create_linear(...), M.pattern_destroy)
end

function M.pattern_create_radial(...)
	return ffi.gc(C.cairo_pattern_create_radial(...), M.pattern_destroy)
end

function M.pattern_create_mesh(...)
	return ffi.gc(C.cairo_pattern_create_mesh(...), M.pattern_destroy)
end

function M.pattern_reference(...)
	return ffi.gc(C.cairo_pattern_reference(...), M.pattern_destroy)
end

function M.scaled_font_create(...)
	return ffi.gc(C.cairo_scaled_font_create(...), M.scaled_font_destroy)
end

function M.scaled_font_reference(...)
	return ffi.gc(C.cairo_scaled_font_reference(...), M.scaled_font_destroy)
end

function M.toy_font_face_create(...)
	return ffi.gc(C.cairo_toy_font_face_create(...), M.font_face_destroy)
end

function M.toy_font_face_create(family, slant, weight)
	return ffi.gc(
		C.cairo_toy_font_face_create(family,
			X('CAIRO_FONT_SLANT_', slant),
			X('CAIRO_FONT_WEIGHT_', weight)
	), M.font_face_destroy)
end

function M.user_font_face_create(...)
	return ffi.gc(C.cairo_user_font_face_create(...), M.font_face_destroy)
end

function M.font_face_reference(...)
	return ffi.gc(C.cairo_font_face_reference(...), M.font_face_destroy)
end

function M.font_options_create()
	return ffi.gc(C.cairo_font_options_create(), M.font_options_destroy)
end

function M.region_create(...)
	return ffi.gc(C.cairo_region_create(...), M.region_destroy)
end

function M.region_create_rectangle(...)
	return ffi.gc(C.cairo_region_create_rectangle(...), M.region_destroy)
end

function M.region_create_rectangles(...)
	return ffi.gc(C.cairo_region_create_rectangles(...), M.region_destroy)
end

function M.region_copy(...)
	return ffi.gc(C.cairo_region_copy(...), M.region_destroy)
end

function M.region_reference(...)
	return ffi.gc(C.cairo_region_reference(...), M.region_destroy)
end

function M.copy_path(...)
	return ffi.gc(C.cairo_copy_path(...), M.path_destroy)
end

function M.copy_path_flat(...)
	return ffi.gc(C.cairo_copy_path_flat(...), M.path_destroy)
end

function M.copy_clip_rectangle_list(...)
	return ffi.gc(C.cairo_copy_clip_rectangle_list(...), M.rectangle_list_destroy)
end

function M.glyph_allocate(...)
	return ffi.gc(C.cairo_glyph_allocate(...), M.glyph_free)
end

function M.text_cluster_allocate(...)
	return ffi.gc(C.cairo_text_cluster_allocate(...), M.text_cluster_free)
end

-- char* return -> string return

M.version = C.cairo_version

function M.version_string()
	return ffi.string(C.cairo_version_string())
end

function M.status_to_string(status)
	return ffi.string(C.cairo_status_to_string(status))
end

local function status_string(self)
	return M.status_to_string(self:status())
end

-- int return -> bool return

local function returns_bool(f)
	return f and function(...)
		return f(...) ~= 0
	end
end
M.in_stroke = returns_bool(M.in_stroke)
M.in_fill = returns_bool(M.in_fill)
M.in_clip = returns_bool(M.in_clip)
M.has_current_point = returns_bool(M.has_current_point)
M.surface_has_show_text_glyphs = returns_bool(M.surface_has_show_text_glyphs)
M.font_options_equal = returns_bool(M.font_options_equal)
M.region_equal = returns_bool(M.region_equal)
M.region_is_empty = returns_bool(M.region_is_empty)
M.region_contains_point = returns_bool(M.region_contains_point)

-- return multiple values instead of passing output buffers

local dx  = ffi.new'double[1]'
local dy  = ffi.new'double[1]'
local dx1 = ffi.new'double[1]'
local dy1 = ffi.new'double[1]'
local dx2 = ffi.new'double[1]'
local dy2 = ffi.new'double[1]'

local getmatrix_function(cfunc)
	return function(self, mt)
		mt = mt or ffi.new'cairo_matrix_t'
		cfunc(self, mt)
		return mt
	end
end
M.get_matrix                   = getmatrix_function(C.cairo_get_matrix)
M.pattern_get_matrix           = getmatrix_function(C.cairo_pattern_get_matrix)
M.get_font_matrix              = getmatrix_function(C.cairo_get_font_matrix)
M.scaled_font_get_font_matrix  = getmatrix_function(C.cairo_scaled_font_get_font_matrix)
M.scaled_font_get_ctm          = getmatrix_function(C.cairo_scaled_font_get_ctm)
M.scaled_font_get_scale_matrix = getmatrix_function(C.cairo_scaled_font_get_scale_matrix)

function M.get_current_point(cr)
	C.cairo_get_current_point(cr, dx, dy)
	return dx[0], dy[0]
end

local function extents_function(f)
	return function(cr)
		f(cr, dx1, dy1, dx2, dy2)
		return dx1[0], dy1[0], dx2[0], dy2[0]
	end
end
M.clip_extents   = extents_function(C.cairo_clip_extents)
M.fill_extents   = extents_function(C.cairo_fill_extents)
M.stroke_extents = extents_function(C.cairo_stroke_extents)
M.path_extents   = extents_function(C.cairo_path_extents)
M.recording_surface_ink_extents = extents_function(C.cairo_recording_surface_ink_extents) --TODO: optional

local surface = ffi.new'cairo_surface_t*[1]'
function M.pattern_get_surface(self, surface)
	C.cairo_pattern_get_surface(self, surface)
	return surface[0]
end

local function point_transform_function(f)
	return function(cr, x, y)
		dx[0], dy[0] = x, y
		f(cr, dx, dy)
		return dx[0], dy[0]
	end
end
M.device_to_user          = point_transform_function(C.cairo_device_to_user)
M.user_to_device          = point_transform_function(C.cairo_user_to_device)
M.user_to_device_distance = point_transform_function(C.cairo_user_to_device_distance)
M.device_to_user_distance = point_transform_function(C.cairo_device_to_user_distance)

function M.surface_get_device_offset(surface)
	C.cairo_surface_get_device_offset(surface, dx, dy)
	return dx[0], dy[0]
end

function M.surface_get_fallback_resolution(surface)
	C.cairo_surface_get_fallback_resolution(surface, dx, dy)
	return dx[0], dy[0]
end

function M.text_extents(cr, s, extents)
	extents = extents or ffi.new'cairo_text_extents_t'
	C.cairo_text_extents(cr, s, extents)
	return extents
end

function M.glyph_extents(cr, glyphs, num_glyphs, extents)
	extents = extents or ffi.new'cairo_text_extents_t'
	C.cairo_glyph_extents(cr, glyphs, num_glyphs, extents)
	return extents
end

function M.font_extents(cr, extents)
	extents = extents or ffi.new'cairo_font_extents_t'
	C.cairo_font_extents(cr, extents)
	return extents
end

function M.scaled_font_extents(sfont, extents)
	extents = extents or ffi.new'cairo_font_extents_t'
	C.cairo_scaled_font_extents(sfont, extents)
	return extents
end

function M.scaled_font_extents(sfont, extents)
	extents = extents or ffi.new'cairo_font_extents_t'
	C.cairo_scaled_font_extents(sfont, extents)
	return extents
end

function M.scaled_font_text_extents(sfont, s, extents)
	extents = extents or ffi.new'cairo_font_extents_t'
	C.cairo_scaled_font_text_extents(sfont, s, extents)
	return extents
end

function M.scaled_font_glyph_extents(sfont, glyphs, num_glyphs, extents)
	extents = extents or ffi.new'cairo_font_extents_t'
	C.cairo_scaled_font_glyph_extents(sfont, glyphs, num_glyphs, extents)
	return extents
end

-- quad beziers addition

function M.quad_curve_to(cr, x1, y1, x2, y2)
	local x0, y0 = cr:get_current_point()
	cr:curve_to((x0 + 2 * x1) / 3,
					(y0 + 2 * y1) / 3,
					(x2 + 2 * x1) / 3,
					(y2 + 2 * y1) / 3,
					x2, y2)
end

function M.rel_quad_curve_to(cr, x1, y1, x2, y2)
	local x0, y0 = cr:get_current_point()
	M.quad_curve_to(cr, x0+x1, y0+y1, x0+x2, y0+y2)
end

-- arcs addition

local pi = math.pi
function M.circle(cr, cx, cy, r)
	cr:new_sub_path()
	cr:arc(cx, cy, r, 0, 2 * pi)
	cr:close_path()
end

function M.ellipse(cr, cx, cy, rx, ry, rotation)
	local mt = cr:get_matrix()
	cr:translate(cx, cy)
	if rotation then cr:rotate(rotation) end
	cr:scale(1, ry/rx)
	cr:circle(0, 0, rx)
	cr:set_matrix(mt)
end

-- matrix additions

function M.matrix_transform(dmt, mt)
	dmt:multiply(mt, dmt)
	return dmt
end

function M.matrix_invertible(mt, tmt)
	tmt = tmt or ffi.new'cairo_matrix_t'
	ffi.copy(tmt, mt, ffi.sizeof(mt))
	return tmt:invert() == 0
end

function M.matrix_safe_transform(dmt, mt)
	if mt:invertible() then dmt:transform(mt) end
end

function M.matrix_skew(mt, ax, ay)
	local sm = ffi.new'cairo_matrix_t'
	sm:init_identity()
	sm.xy = math.tan(ax)
	sm.yx = math.tan(ay)
	mt:transform(sm)
end

function M.matrix_rotate_around(mt, cx, cy, angle)
	mt:translate(cx, cy)
	mt:rotate(angle)
	mt:translate(-cx, -cy)
end

function M.matrix_scale_around(mt, cx, cy, ...)
	mt:translate(cx, cy)
	mt:scale(...)
	mt:translate(-cx, -cy)
end

function M.matrix_copy(mt)
	local dmt = ffi.new'cairo_matrix_t'
	ffi.copy(dmt, mt, ffi.sizeof(mt))
	return dmt
end

function M.matrix_init_matrix(dmt, mt)
	ffi.copy(dmt, mt, ffi.sizeof(mt))
end

-- context additions

function M.safe_transform(cr, mt)
	if mt:invertible() then cr:transform(mt) end
end

function M.rotate_around(cr, cx, cy, angle)
	M.translate(cr, cx, cy)
	M.rotate(cr, angle)
	M.translate(cr, -cx, -cy)
end

function M.scale_around(cr, cx, cy, ...)
	M.translate(cr, cx, cy)
	M.scale(cr, ...)
	M.translate(cr, -cx, -cy)
end

function M.skew(cr, ax, ay)
	local sm = ffi.new'cairo_matrix_t'
	sm:init_identity()
	sm.xy = math.tan(ax)
	sm.yx = math.tan(ay)
	cr:transform(sm)
end

-- surface additions

function M.surface_apply_alpha(surface, alpha)
	if alpha >= 1 then return end
	local cr = surface:create_context()
	cr:set_source_rgba(0,0,0,alpha)
	cr:set_operator(cairo.CAIRO_OPERATOR_DEST_IN) --alphas are multiplied, dest. color is preserved
	cr:paint()
	cr:free()
end

local image_surface_bpp = {
    [C.CAIRO_FORMAT_ARGB32] = 32,
    [C.CAIRO_FORMAT_RGB24] = 32,
    [C.CAIRO_FORMAT_A8] = 8,
    [C.CAIRO_FORMAT_A1] = 1,
    [C.CAIRO_FORMAT_RGB16_565] = 16,
    [C.CAIRO_FORMAT_RGB30] = 30,
}
function M.image_surface_get_bpp(surface)
	return image_surface_bpp[tonumber(surface:get_image_format())]
end

local bitmap_formats = {}
for k,v in pairs(cairo_formats) do
	bitmap_formats[v] = k
end
function M.image_surface_get_bitmap(surface)
	return {
		data   = surface:get_image_data(),
		format = bitmap_formats[surface:get_image_format()],
		w      = surface:get_image_width(),
		h      = surface:get_image_height(),
		stride = surface:get_image_stride(),
	}
end

--return a getpixel function for a surface that returns pixel components based on surface image format:
--for ARGB32: getpixel(x, y) -> r, g, b, a
--for RGB24:  getpixel(x, y) -> r, g, b
--for A8:     getpixel(x, y) -> a
--for A1:     getpixel(x, y) -> a
--for RGB16:  getpixel(x, y) -> r, g, b
--for RGB30:  getpixel(x, y) -> r, g, b
function M.image_surface_get_pixel_function(surface)
	local data   = surface:get_image_data()
	local format = surface:get_image_format()
	local w      = surface:get_image_width()
	local h      = surface:get_image_height()
	local stride = surface:get_image_stride()
	local getpixel
	data = ffi.cast('uint8_t*', data)
	if format == C.CAIRO_FORMAT_ARGB32 then
		if ffi.abi'le' then
			error'NYI'
		else
			error'NYI'
		end
	elseif format == C.CAIRO_FORMAT_RGB24 then
		function getpixel(x, y)
			assert(x < w and y < h and x >= 0 and y >= 0, 'out of range')
			return
				data[y * stride + x * 4 + 2],
				data[y * stride + x * 4 + 1],
				data[y * stride + x * 4 + 0]
		end
	elseif format == C.CAIRO_FORMAT_A8 then
		function getpixel(x, y)
			assert(x < w and y < h and x >= 0 and y >= 0, 'out of range')
			return data[y * stride + x]
		end
	elseif format == C.CAIRO_FORMAT_A1 then
		if ffi.abi'le' then
			error'NYI'
		else
			error'NYI'
		end
	elseif format == C.CAIRO_FORMAT_RGB16_565 then
		error'NYI'
	elseif format == C.CAIRO_FORMAT_RGB30 then
		error'NYI'
	else
		error'unsupported image format'
	end
	return getpixel
end

--return a setpixel function analog to getpixel above.
function M.image_surface_set_pixel_function(surface)
	local data   = surface:get_image_data()
	local format = surface:get_image_format()
	local w      = surface:get_image_width()
	local h      = surface:get_image_height()
	local stride = surface:get_image_stride()
	data = ffi.cast('uint8_t*', data)
	local setpixel
	if format == C.CAIRO_FORMAT_ARGB32 then
		if ffi.abi'le' then
			error'NYI'
		else
			error'NYI'
		end
	elseif format == C.CAIRO_FORMAT_RGB24 then
		function setpixel(x, y, r, g, b)
			assert(x < w and y < h and x >= 0 and y >= 0, 'out of range')
			data[y * stride + x * 4 + 2] = r
			data[y * stride + x * 4 + 1] = g
			data[y * stride + x * 4 + 0] = b
		end
	elseif format == C.CAIRO_FORMAT_A8 then
		function setpixel(x, y, a)
			assert(x < w and y < h and x >= 0 and y >= 0, 'out of range')
			data[y * stride + x] = a
		end
	elseif format == C.CAIRO_FORMAT_A1 then
		if ffi.abi'le' then
			error'NYI'
		else
			error'NYI'
		end
	elseif format == C.CAIRO_FORMAT_RGB16_565 then
		error'NYI'
	elseif format == C.CAIRO_FORMAT_RGB30 then
		error'NYI'
	else
		error'unsupported image format'
	end
	return setpixel
end

-- luaization overrides

local function flagsetter(name, prefix)
	local cfunc = C['cairo_'..name]
	M[name] = function(self, flag)
		cfunc(self, X(prefix, flag)
	end
end

flagsetter('push_group_with_content', 'CAIRO_CONTENT_')
flagsetter('set_operator', 'CAIRO_OPERATOR_')
flagsetter('set_antialias', 'CAIRO_ANTIALIAS_')
flagsetter('set_fill_rule', 'CAIRO_FILL_RULE_')
flagsetter('set_line_cap', 'CAIRO_LINE_CAP_')
flagsetter('set_line_join', 'CAIRO_LINE_JOIN_')

function M.set_dash(cr, dashes, num_dashes, offset)
	if type(dashes) == 'table' then
		offset = num_dashes
		dashes = ffi.new('double[?]', #dashes, dashes)
	end
	C.cairo_set_dash(cr, dashes, num_dashes, offset)
end

local offset = ffi.new'double[1]'
function M.get_dash(cr, dashes)
	if type(dashes) == 'cdata' then
		C.cairo_get_dash(cr, dashes, offset)
		return dashes, offset
	else
		local n = M.get_dash_count(cr)
		dashes = ffi.new('double[?]', n)
		C.cairo_get_dash(cr, dashes, offset)
		local t = {}
		for i=1,n do
			t[i] = dashes[i-1]
		end
		return t, offset[0]
	end
end

flagsetter('font_options_set_antialias', 'CAIRO_ANTIALIAS_')
flagsetter('font_options_set_subpixel_order', 'CAIRO_SUBPIXEL_ORDER_')
flagsetter('font_options_set_hint_style', 'CAIRO_HINT_STYLE_')
flagsetter('font_options_set_hint_metrics', 'CAIRO_HINT_METRICS_')
flagsetter('font_options_set_lcd_filter', 'CAIRO_LCD_FILTER_') --TODO: optional
flagsetter('font_options_set_round_glyph_positions', 'CAIRO_ROUND_GLYPH_POS_') --TODO: optional

function M.cairo_select_font_face(cr, family, slant, weight)
	C.cairo_select_font_face(cr, family,
		X('CAIRO_FONT_SLANT_', slant),
		X('CAIRO_FONT_WEIGHT_', weight))
end

-- create/return created font options object

local function get_font_options_function(cfunc)
	return function(sr, fopt)
		fopt = fopt or M.font_options_create()
		cfunc(sr, fopt)
		return fopt
	end
end
M.get_font_options = get_font_options_function(C.cairo_get_font_options)
M.surface_get_font_options = get_font_options_function(C.cairo_surface_get_font_options)
M.scaled_font_get_font_options = get_font_options_function(C.scaled_font_get_font_options)

-- metamethods

ffi.metatype('cairo_t', {__index = {
	reference = M.reference,
	destroy = M.destroy,
	free = free_ref_counted,
	get_reference_count = M.get_reference_count,
	get_user_data = M.get_user_data,
	set_user_data = M.set_user_data,
	save = M.save,
	restore = M.restore,
	push_group = M.push_group,
	pop_group = M.pop_group,
	pop_group_to_source = M.pop_group_to_source,
	set_operator = M.set_operator,
	set_source = M.set_source,
	set_source_rgb = M.set_source_rgb,
	set_source_rgba = M.set_source_rgba,
	set_source_surface = M.set_source_surface,
	set_tolerance = M.set_tolerance,
	set_antialias = M.set_antialias,
	set_fill_rule = M.set_fill_rule,
	set_line_width = M.set_line_width,
	set_line_cap = M.set_line_cap,
	set_line_join = M.set_line_join,
	set_dash = M.set_dash,
	set_miter_limit = M.set_miter_limit,
	translate = M.translate,
	scale = M.scale,
	rotate = M.rotate,
	rotate_around = M.rotate_around,
	scale_around = M.scale_around,
	transform = M.transform,
	safe_transform = M.safe_transform,
	set_matrix = M.set_matrix,
	identity_matrix = M.identity_matrix,
	skew = M.skew,
	user_to_device = M.user_to_device,
	user_to_device_distance = M.user_to_device_distance,
	device_to_user = M.device_to_user,
	device_to_user_distance = M.device_to_user_distance,
	new_path = M.new_path,
	move_to = M.move_to,
	new_sub_path = M.new_sub_path,
	line_to = M.line_to,
	curve_to = M.curve_to,
	quad_curve_to = M.quad_curve_to,
	arc = M.arc,
	arc_negative = M.arc_negative,
	circle = M.circle,
	ellipse = M.ellipse,
	--arc_to = M.arc_to, --abandoned? cairo_arc_to(x1, y1, x2, y2, radius)
	rel_move_to = M.rel_move_to,
	rel_line_to = M.rel_line_to,
	rel_curve_to = M.rel_curve_to,
	rel_quad_curve_to = M.rel_quad_curve_to,
	rectangle = M.rectangle,
	--stroke_to_path = M.stroke_to_path, --abandoned :(
	close_path = M.close_path,
	path_extents = M.path_extents,
	paint = M.paint,
	paint_with_alpha = M.paint_with_alpha,
	mask = M.mask,
	mask_surface = M.mask_surface,
	stroke = M.stroke,
	stroke_preserve = M.stroke_preserve,
	fill = M.fill,
	fill_preserve = M.fill_preserve,
	copy_page = M.copy_page,
	show_page = M.show_page,
	in_stroke = M.in_stroke,
	in_fill = M.in_fill,
	in_clip = M.in_clip,
	stroke_extents = M.stroke_extents,
	fill_extents = M.fill_extents,
	reset_clip = M.reset_clip,
	clip = M.clip,
	clip_preserve = M.clip_preserve,
	clip_extents = M.clip_extents,
	copy_clip_rectangle_list = M.copy_clip_rectangle_list,
	select_font_face = M.select_font_face,
	set_font_size = M.set_font_size,
	set_font_matrix = M.set_font_matrix,
	get_font_matrix = M.get_font_matrix,
	set_font_options = M.set_font_options,
	get_font_options = M.get_font_options,
	set_font_face = M.set_font_face,
	get_font_face = M.get_font_face,
	set_scaled_font = M.set_scaled_font,
	get_scaled_font = M.get_scaled_font,
	show_text = M.show_text,
	show_glyphs = M.show_glyphs,
	show_text_glyphs = M.show_text_glyphs,
	text_path = M.text_path,
	glyph_path = M.glyph_path,
	text_extents = M.text_extents,
	glyph_extents = M.glyph_extents,
	font_extents = M.font_extents,
	get_operator = M.get_operator,
	get_source = M.get_source,
	get_tolerance = M.get_tolerance,
	get_antialias = M.get_antialias,
	has_current_point = M.has_current_point,
	get_current_point = M.get_current_point,
	get_fill_rule = M.get_fill_rule,
	get_line_width = M.get_line_width,
	get_line_cap = M.get_line_cap,
	get_line_join = M.get_line_join,
	get_miter_limit = M.get_miter_limit,
	get_dash_count = M.get_dash_count,
	get_dash = M.get_dash,
	get_matrix = M.get_matrix,
	get_target = M.get_target,
	get_group_target = M.get_group_target,
	copy_path = M.copy_path,
	copy_path_flat = M.copy_path_flat,
	append_path = M.append_path,
	status = M.status,
	status_string = status_string,
}})

ffi.metatype('cairo_surface_t', {__index = {
	create_context = M.create,
	create_similar = M.surface_create_similar,
	create_similar_image = M.surface_create_similar_image,
	create_for_rectangle = M.surface_create_for_rectangle,
	create_observer = M.surface_create_observer,
	map_to_image = M.surface_map_to_image,
	unmap_image = M.surface_unmap_image,
	reference = M.surface_reference,
	finish = M.surface_finish,
	destroy = M.surface_destroy,
	free = free_ref_counted,
	get_device = M.surface_get_device,
	get_reference_count = M.surface_get_reference_count,
	status = M.surface_status,
	status_string = status_string,
	get_type = M.surface_get_type,
	get_content = M.surface_get_content,
	write_to_png = _C'cairo_surface_write_to_png',
	write_to_png_stream = _C'cairo_surface_write_to_png_stream',
	get_user_data = M.surface_get_user_data,
	set_user_data = M.surface_set_user_data,
	get_mime_data = M.surface_get_mime_data,
	set_mime_data = M.surface_set_mime_data,
	get_font_options = M.surface_get_font_options,
	flush = M.surface_flush,
	mark_dirty = M.surface_mark_dirty,
	mark_dirty_rectangle = M.surface_mark_dirty_rectangle,
	set_device_offset = M.surface_set_device_offset,
	get_device_offset = M.surface_get_device_offset,
	set_fallback_resolution = M.surface_set_fallback_resolution,
	get_fallback_resolution = M.surface_get_fallback_resolution,
	copy_page = M.surface_copy_page,
	show_page = M.surface_show_page,
	has_show_text_glyphs = M.surface_has_show_text_glyphs,
	create_pattern = M.pattern_create_for_surface,
	apply_alpha = M.surface_apply_alpha,

	--for image surfaces
	get_image_data = M.image_surface_get_data,
	get_image_format = M.image_surface_get_format,
	get_image_width = M.image_surface_get_width,
	get_image_height = M.image_surface_get_height,
	get_image_stride = M.image_surface_get_stride,
	get_image_bpp = M.image_surface_get_bpp,
	get_image_bitmap = M.image_surface_get_bitmap,
	get_image_pixel_function = M.image_surface_get_pixel_function,
	set_image_pixel_function = M.image_surface_set_pixel_function,

	--for recording surfaces
	recording_ink_extents = M.recording_surface_ink_extents,
}})

ffi.metatype('cairo_device_t', {__index = {
	reference = M.device_reference,
	get_type = M.device_get_type,
	status = M.device_status,
	status_string = status_string,
	acquire = M.device_acquire,
	release = M.device_release,
	flush = M.device_flush,
	finish = M.device_finish,
	destroy = M.device_destroy,
	free = free_ref_counted,
	get_reference_count = M.device_get_reference_count,
	get_user_data = M.device_get_user_data,
	set_user_data = M.device_set_user_data,
}})

ffi.metatype('cairo_pattern_t', {__index = {
	reference = M.pattern_reference,
	destroy = M.pattern_destroy,
	free = free_ref_counted,
	get_reference_count = M.pattern_get_reference_count,
	status = M.pattern_status,
	status_string = status_string,
	get_user_data = M.pattern_get_user_data,
	set_user_data = M.pattern_set_user_data,
	get_type = M.pattern_get_type,
	add_color_stop_rgb = M.pattern_add_color_stop_rgb,
	add_color_stop_rgba = M.pattern_add_color_stop_rgba,
	set_matrix = M.pattern_set_matrix,
	get_matrix = M.pattern_get_matrix,
	set_extend = M.pattern_set_extend,
	get_extend = M.pattern_get_extend,
	set_filter = M.pattern_set_filter,
	get_filter = M.pattern_get_filter,
	get_rgba = M.pattern_get_rgba,
	get_surface = M.pattern_get_surface,
	get_color_stop_rgba = M.pattern_get_color_stop_rgba,
	get_color_stop_count = M.pattern_get_color_stop_count,
	get_linear_points = M.pattern_get_linear_points,
	get_radial_circles = M.pattern_get_radial_circles,
	--meshes
	mesh_begin_patch = M.mesh_pattern_begin_patch,
	mesh_end_patch = M.mesh_pattern_end_patch,
}})

ffi.metatype('cairo_scaled_font_t', {__index = {
	reference = M.scaled_font_reference,
	destroy = M.scaled_font_destroy,
	free = free_ref_counted,
	get_reference_count = M.scaled_font_get_reference_count,
	status = M.scaled_font_status,
	status_string = status_string,
	get_type = M.scaled_font_get_type,
	get_user_data = M.scaled_font_get_user_data,
	set_user_data = M.scaled_font_set_user_data,
	extents = M.scaled_font_extents,
	text_extents = M.scaled_font_text_extents,
	glyph_extents = M.scaled_font_glyph_extents,
	text_to_glyphs = M.scaled_font_text_to_glyphs,
	get_font_face = M.scaled_font_get_font_face,
	get_font_matrix = M.scaled_font_get_font_matrix,
	get_ctm = M.scaled_font_get_ctm,
	get_scale_matrix = M.scaled_font_get_scale_matrix,
	get_font_options = M.scaled_font_get_font_options,
}})

ffi.metatype('cairo_font_face_t', {__index = {
	reference = M.font_face_reference,
	destroy = M.font_face_destroy,
	free = free_ref_counted,
	get_reference_count = M.font_face_get_reference_count,
	status = M.font_face_status,
	status_string = status_string,
	get_type = M.font_face_get_type,
	get_user_data = M.font_face_get_user_data,
	set_user_data = M.font_face_set_user_data,
	create_scaled_font = M.scaled_font_create,
	scaled_font_create = M.scaled_font_create,
	toy_get_family = M.toy_font_face_get_family,
	toy_get_slant = M.toy_font_face_get_slant,
	toy_get_weight = M.toy_font_face_get_weight,
	user_set_init_func = M.user_font_face_set_init_func,
	user_set_render_glyph_func = M.user_font_face_set_render_glyph_func,
	user_set_text_to_glyphs_func = M.user_font_face_set_text_to_glyphs_func,
	user_set_unicode_to_glyph_func = M.user_font_face_set_unicode_to_glyph_func,
	user_get_init_func = M.user_font_face_get_init_func,
	user_get_render_glyph_func = M.user_font_face_get_render_glyph_func,
	user_get_text_to_glyphs_func = M.user_font_face_get_text_to_glyphs_func,
	user_get_unicode_to_glyph_func = M.user_font_face_get_unicode_to_glyph_func,
}})

ffi.metatype('cairo_font_options_t', {__index = {
	copy = M.font_options_copy,
	free = M.font_options_destroy,
	status = M.font_options_status,
	status_string = status_string,
	merge = M.font_options_merge,
	equal = M.font_options_equal,
	hash = M.font_options_hash,
	set_antialias = M.font_options_set_antialias,
	get_antialias = M.font_options_get_antialias,
	set_subpixel_order = M.font_options_set_subpixel_order,
	get_subpixel_order = M.font_options_get_subpixel_order,
	set_hint_style = M.font_options_set_hint_style,
	get_hint_style = M.font_options_get_hint_style,
	set_hint_metrics = M.font_options_set_hint_metrics,
	get_hint_metrics = M.font_options_get_hint_metrics,
	--private functions, only available in our custom build
	set_lcd_filter = M.font_options_set_lcd_filter,
	get_lcd_filter = M.font_options_get_lcd_filter,
	set_round_glyph_positions = M.font_options_set_round_glyph_positions,
	get_round_glyph_positions = M.font_options_get_round_glyph_positions,
}, __eq = M.font_options_equal,
})

ffi.metatype('cairo_region_t', {__index = {
	create = M.region_create,
	create_rectangle = M.region_create_rectangle,
	create_rectangles = M.region_create_rectangles,
	copy = M.region_copy,
	reference = M.region_reference,
	destroy = M.region_destroy,
	free = free_ref_counted,
	equal = M.region_equal,
	status = M.region_status,
	status_string = status_string,
	get_extents = M.region_get_extents,
	num_rectangles = M.region_num_rectangles,
	get_rectangle = M.region_get_rectangle,
	is_empty = M.region_is_empty,
	contains_rectangle = M.region_contains_rectangle,
	contains_point = M.region_contains_point,
	translate = M.region_translate,
	subtract = M.region_subtract,
	subtract_rectangle = M.region_subtract_rectangle,
	intersect = M.region_intersect,
	intersect_rectangle = M.region_intersect_rectangle,
	union = M.region_union,
	union_rectangle = M.region_union_rectangle,
	xor = M.region_xor,
	xor_rectangle = M.region_xor_rectangle,
}})

ffi.metatype('cairo_path_t', {__index = {
	free = M.path_destroy,
}})

ffi.metatype('cairo_rectangle_list_t', {__index = {
	free = M.rectangle_list_destroy,
}})

ffi.metatype('cairo_glyph_t', {__index = {
	free = M.glyph_free,
}})
ffi.metatype('cairo_text_cluster_t', {__index = {
	free = M.text_cluster_free,
}})

local function cairo_matrix_tostring(mt)
	return string.format('[%12f%12f]\n[%12f%12f]\n[%12f%12f]',
		mt.xx, mt.yx, mt.xy, mt.yy, mt.x0, mt.y0)
end

ffi.metatype('cairo_matrix_t', {__index = {
	init = M.matrix_init,
	init_identity = M.matrix_init_identity,
	init_translate = M.matrix_init_translate,
	init_scale = M.matrix_init_scale,
	init_rotate = M.matrix_init_rotate,
	translate = M.matrix_translate,
	scale = M.matrix_scale,
	rotate = M.matrix_rotate,
	rotate_around = M.matrix_rotate_around,
	scale_around = M.matrix_scale_around,
	invert = M.matrix_invert,
	multiply = M.matrix_multiply,
	transform_distance = M.matrix_transform_distance,
	transform_point = M.matrix_transform_point,
	--additions
	transform = M.matrix_transform,
	invertible = M.matrix_invertible,
	safe_transform = M.matrix_safe_transform,
	skew = M.matrix_skew,
	copy = M.matrix_copy,
	init_matrix = M.matrix_init_matrix,
}, __tostring = cairo_matrix_tostring})

ffi.metatype('cairo_rectangle_int_t', {__index = {
	create_region = M.region_create_rectangle,
}})

return M
