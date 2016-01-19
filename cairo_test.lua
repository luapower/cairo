local cairo = require'cairo'
local bitmap = require'bitmap'
local ffi = require'ffi'
local C = cairo.C

print('cairo version: ', cairo.version())
print('cairo version string: ', cairo.version_string())

local function bmp_surface(w, h, format)
	local bmp = bitmap.new(w, h, format or 'bgra8')
	return cairo.create_image_surface(bmp)
end

local sr = bmp_surface(500, 300)
local cr = sr:create_context()

cr:ref()
assert(cr:refcount() == 2)
cr:unref()

cr:save()
cr:restore()

cr:push_group()
local patt = cr:pop_group()
patt:free()

cr:push_group()
cr:pop_group_to_source()

cr:operator'darken'
assert(cr:operator() == 'darken')

--TODO
--[[
cr:push_group()
local patt = cr:pop_group()
cr:source(patt)
assert(patt:refcount() == 2)
cr:source(cairo.NULL)
patt:unref()
]]

cr:source_rgb(1, 1, 1)
cr:source_rgba(1, 1, 1, 1)

--[[
local sr1 = bmp_surface(500, 300)
cr:source_surface(sr1)
cr:source(cairo.NULL)
sr1:unref()
]]

assert(cr:tolerance() == 0.1)
cr:tolerance(1/16)
assert(cr:tolerance() == 1/16)

assert(cr:antialias() == 'default')
cr:antialias'none'
assert(cr:antialias() == 'none')

assert(cr:fill_rule() == 'winding')
cr:fill_rule'even_odd'
assert(cr:fill_rule() == 'even_odd')

cr:line_width(5.5)
assert(cr:line_width() == 5.5)

assert(cr:line_cap() == 'butt')
cr:line_cap'round'
assert(cr:line_cap() == 'round')

assert(cr:line_join() == 'miter')
cr:line_join'round'
assert(cr:line_join() == 'round')

assert(#cr:dash() == 0)
cr:dash{5, 3, 2}
assert(cr:dash()[2] == 3)
assert(cr:dash_count() == 3)

assert(cr:miter_limit() == 10)
cr:miter_limit(7)
assert(cr:miter_limit() == 7)

cr:matrix(cairo.matrix(1, 2, 3, 4, 5, 6))
assert(cr:matrix().x0 == 5)
cr:identity_matrix()
cr:translate(7, 0)
assert(cr:matrix().x0 == 7)
cr:scale(2, 1)
assert(cr:matrix().xx == 2)
cr:rotate(math.pi)
assert(cr:matrix().xx == -2)
cr:identity_matrix()
cr:transform(cairo.matrix(-1, -1, 1, 0, 0, 0))
assert(cr:matrix().xx == -1)

cr:identity_matrix()
cr:translate(10, 10)
cr:scale(2, 2)
local x, y = cr:user_to_device(2, 2)
assert(x == 14 and y == 14)
local x, y = cr:user_to_device_distance(2, 2)
assert(x == 4 and y == 4)
local x, y = cr:device_to_user(4, 4)
assert(x == -3 and y == -3)
local x, y = cr:device_to_user_distance(4, 4)
assert(x == 2 and y == 2)

cr:new_path()
cr:move_to(2, 2)
cr:line_to(2, 2)
cr:new_sub_path()
cr:move_to(5, 5)
cr:line_to(2, 2)
cr:curve_to(2, 3, 4, 5, 6, 7)
cr:quad_curve_to(2, 3, 4, 5)
cr:arc(5, 5, 7, math.pi/2, math.pi/4)
cr:arc_negative(5, 5, 7, math.pi/2, math.pi/4)
cr:rel_move_to(2, 2)
cr:rel_line_to(2, 2)
cr:rel_curve_to(2, 3, 4, 5, 6, 7)
cr:rel_quad_curve_to(2, 3, 4, 5)
cr:rectangle(1, 2, 3, 4)
cr:close_path()
print(cr:path_extents())
cr:paint()
cr:paint_with_alpha(0.5)
--cr:mask(patt)
cr:stroke()
cr:stroke_preserve()
cr:fill()
cr:fill_preserve()

cr:copy_page()
cr:show_page()

print(cr:in_stroke(1, 2))
print(cr:in_fill(2, 3))
print(cr:in_clip(3, 4))

print(cr:stroke_extents())
print(cr:fill_extents())

cr:reset_clip()
cr:clip()
cr:clip_preserve()

print(cr:clip_extents())

local rl = cr:copy_clip_rectangle_list()
--print(rl:count())

local glyphs = cairo.allocate_glyphs(10)
glyphs:free()

local cl = cairo.allocate_text_clusters(10)
cl:free()

local fopt = cairo.create_font_options()
fopt:copy():free()
assert(fopt:status_string():match'no error')
local fopt1 = fopt:copy()
fopt:merge(fopt1)
assert(fopt:equal(fopt1))
assert(fopt:hash() == fopt1:hash())
assert(fopt ~= fopt1) --__eq wouldn't have worked here anyway (pointers)
fopt1:free()

assert(fopt:antialias() == 'default')
fopt:antialias'good'
assert(fopt:antialias() == 'good')

assert(fopt:subpixel_order() == 'default')
fopt:subpixel_order'vrgb'
assert(fopt:subpixel_order() == 'vrgb')

assert(fopt:hint_style() == 'default')
fopt:hint_style'slight'
assert(fopt:hint_style() == 'slight')

assert(fopt:hint_metrics() == 'default')
fopt:hint_metrics'on'
assert(fopt:hint_metrics() == 'on')

fopt:free()

cr:select_font_face('Arial', 'italic', 'bold')
cr:font_size(10)

cr:font_matrix(cairo.matrix(1, 2, 3, 4, 5, 6))
assert(cr:font_matrix().x0 == 5)

local fopt = cairo.create_font_options()
fopt:antialias'good'
cr:font_options(fopt)
assert(cr:font_options():antialias() == 'good')

print(cr:font_face()) --TODO: set it
print(cr:scaled_font()) --TODO: set it

cr:show_text'hello'
local glyphs = cairo.allocate_glyphs(5)
cr:show_glyphs(glyphs, 5)

local clusters = cairo.allocate_text_clusters(5)
cr:show_text_glyphs('hello', 5, glyphs, 5, clusters, 5)

cr:text_path'A'
cr:glpyh_path(glyphs, 5)
print(cr:text_extents'hello')
print(cr:glyph_extents(glyphs, 5))
print(cr:font_extents())

cr:free()
sr:free()

local face = cr:font_face()
face:ref()
assert(face:refcount() == 2)
face:unref()
assert(face:status() == 0)
assert(face:type() == 'toy')

--[[
local fopt = ffi.gc(cairo.create_font_options(), nil)
local mt = cairo.matrix()
local sfont = face:create_scaled_font(mt, mt, fopt)
sfont:free()
]]

--[==[
map('CAIRO_FONT_TYPE_', {
	'TOY',
	'FT',
	'WIN32',
	'QUARTZ',
	'USER',
})


local sfont = {}

sfont.ref = ref_func(C.cairo_scaled_font_reference, C.cairo_scaled_font_destroy)
sfont.destroy = destroy_func(C.cairo_scaled_font_destroy)
sfont.free = free
sfont.refcount = C.cairo_scaled_font_get_reference_count
sfont.status = C.cairo_scaled_font_status
sfont.status_string = status_string
sfont.type = getflag_func(C.cairo_scaled_font_get_type, 'CAIRO_FONT_TYPE_')
sfont.extents = fexout_func(C.cairo_scaled_font_extents)
sfont.text_extents = texout2_func(C.cairo_scaled_font_text_extents)
sfont.glyph_extents = texout3_func(C.cairo_scaled_font_glyph_extents)

local glyphs_buf = ffi.new'cairo_glyph_t*[1]'
local num_glyphs_buf = ffi.new'int[1]'
local clusters_buf = ffi.new'cairo_text_cluster_t*[1]'
local num_clusters_buf = ffi.new'int[1]'
local cluster_flags_buf = ffi.new'cairo_text_cluster_flags_t[1]'

function sfont.text_to_glyphs(sfont, x, y, s, slen, glyphs, num_glyphs, clusters, num_clusters)

sfont.font_face = C.cairo_scaled_font_get_font_face --weak ref
sfont.font_matrix = mtout_func(C.cairo_scaled_font_get_font_matrix)
sfont.ctm = mtout_func(C.cairo_scaled_font_get_ctm)
sfont.scale_matrix = mtout_func(C.cairo_scaled_font_get_scale_matrix)
sfont.font_options = foptout_func(C.cairo_scaled_font_get_font_options)
function M.create_toy_font_face(family, slant, weight)

face.family = str_func(C.cairo_toy_font_face_get_family)
face.slang = getflag_func(C.cairo_toy_font_face_get_slant, 'CAIRO_FONT_SLANT_')
face.weight = getflag_func(C.cairo_toy_font_face_get_weight, 'CAIRO_FONT_WEIGHT_')

M.create_user_font_face = ref_func(C.cairo_user_font_face_create, C.cairo_font_face_destroy)

face.init_func = getset_func(
face.render_glyph_func = getset_func(
face.text_to_glyphs_func = getset_func(
face.unicode_to_glyph_func = getset_func(
cr.has_current_point = bool_func(C.cairo_has_current_point)
cr.current_point = d2out_func(C.cairo_get_current_point)
cr.target = C.cairo_get_target --weak ref
cr.group_target = C.cairo_get_group_target --weak ref

map('CAIRO_PATH_', {
	'MOVE_TO',
	'LINE_TO',
	'CURVE_TO',
	'CLOSE_PATH',
})

cr.copy_path = ref_func(C.cairo_copy_path, C.cairo_path_destroy)
cr.copy_path_flat = ref_func(C.cairo_copy_path, C.cairo_path_destroy)
cr.append_path = C.cairo_append_path

path.destroy = destroy_func(C.cairo_path_destroy)
path.status = C.cairo_status
path.status_string = status_string

M.status_to_string = str_func(C.cairo_status_to_string)

dev.ref = ref_func(C.cairo_device_reference, C.cairo_device_destroy)

map('CAIRO_DEVICE_TYPE_', {
	'DRM',
	'GL',
	'SCRIPT',
	'XCB',
	'XLIB',
	'XML',
	'COGL',
	'WIN32',
	'INVALID',
})

dev.type = getflag_func(C.cairo_device_get_type, 'CAIRO_DEVICE_TYPE_')
dev.status = C.cairo_device_status
dev.status_string = status_string
dev.acquire = C.cairo_device_acquire
dev.release = C.cairo_device_release
dev.flush = C.cairo_device_flush
dev.finish = C.cairo_device_finish
dev.destroy = destroy_func(C.cairo_device_destroy)
dev.free = free
dev.refcount = C.cairo_device_get_reference_count

sr.create_context = ref_func(C.cairo_create, C.cairo_destroy)
sr.create_similar_surface = ref_func(function(sr, content, w, h)
sr.create_similar_image_surface = ref_func(function(sr, format, w, h)

sr.map_to_image = function(sr, x, y, w, h)
sr.unmap_image = function(sr, isr)

sr.create_subsurface = ref_func(C.cairo_surface_create_for_rectangle, C.cairo_surface_destroy)

map('CAIRO_SURFACE_OBSERVER_', {
	'NORMAL',
	'RECORD_OPERATIONS',
})

sr.create_observer_surface = function(sr, mode)

sr.add_paint_callback = C.cairo_surface_observer_add_paint_callback
sr.add_mask_callback = C.cairo_surface_observer_add_mask_callback
sr.add_fill_callback = C.cairo_surface_observer_add_fill_callback
sr.add_stroke_callback = C.cairo_surface_observer_add_stroke_callback
sr.add_glyphs_callback = C.cairo_surface_observer_add_glyphs_callback
sr.add_flush_callback = C.cairo_surface_observer_add_flush_callback
sr.add_finish_callback = C.cairo_surface_observer_add_finish_callback
sr.print = C.cairo_surface_observer_print
sr.elapsed = C.cairo_surface_observer_elapsed

dev.print = C.cairo_device_observer_print
dev.elapsed = C.cairo_device_observer_elapsed
dev.paint_elapsed = C.cairo_device_observer_paint_elapsed
dev.mask_elapsed = C.cairo_device_observer_mask_elapsed
dev.fill_elapsed = C.cairo_device_observer_fill_elapsed
dev.stroke_elapsed = C.cairo_device_observer_stroke_elapsed
dev.glyphs_elapsed = C.cairo_device_observer_glyphs_elapsed

sr.ref = ref_func(C.cairo_surface_reference, C.cairo_surface_destroy)
sr.finish = C.cairo_surface_finish
sr.destroy = destroy_func(C.cairo_surface_destroy)
sr.free = free

sr.device = ptr_func(C.cairo_surface_get_device) --weak ref
sr.refcount = C.cairo_surface_get_reference_count
sr.status = C.cairo_surface_status
sr.status_string = status_string

map('CAIRO_SURFACE_TYPE_', {
	'IMAGE',
	'PDF',
	'PS',
	'XLIB',
	'XCB',
	'GLITZ',
	'QUARTZ',
	'WIN32',
	'BEOS',
	'DIRECTFB',
	'SVG',
	'OS2',
	'WIN32_PRINTING',
	'QUARTZ_IMAGE',
	'SCRIPT',
	'QT',
	'RECORDING',
	'VG',
	'GL',
	'DRM',
	'TEE',
	'XML',
	'SKIA',
	'SUBSURFACE',
	'COGL',
})

sr.type = getflag_func(C.cairo_surface_get_type, 'CAIRO_SURFACE_TYPE_')
sr.content = getflag_func(C.cairo_surface_get_content, 'CAIRO_CONTENT_T')

sr.write_to_png = _C.cairo_surface_write_to_png
sr.write_to_png_stream = C.cairo_surface_write_to_png_stream

local data_buf = ffi.new'void*[1]'
local len_buf = ffi.new'unsigned long[1]'

sr.mime_data = function(sr, mime_type, data, len, destroy, closure)

sr.supports_mime_type = bool_func(C.cairo_surface_supports_mime_type)

sr.font_options = foptout_func(C.cairo_surface_get_font_options)
sr.flush = C.cairo_surface_flush

sr.mark_dirty = function(sr, x, y, w, h)

sr.device_offset = getset_func(d2out_func(C.cairo_surface_get_device_offset), C.cairo_surface_set_device_offset)
sr.fallback_resolution = getset_func(d2out_func(C.cairo_surface_get_fallback_resolution), C.cairo_surface_set_fallback_resolution)

sr.copy_page = C.cairo_surface_copy_page
sr.show_page = C.cairo_surface_show_page
sr.has_show_text_glyphs = bool_func(C.cairo_surface_has_show_text_glyphs)

M.create_image_surface = ref_func(function(fmt, w, h)

M.format_stride_for_width = C.cairo_format_stride_for_width

sr.data = C.cairo_image_surface_get_data
sr.format = getflag_func(C.cairo_image_surface_get_format, 'CAIRO_FORMAT_')
sr.width = C.cairo_image_surface_get_width
sr.height = C.cairo_image_surface_get_height
sr.stride = C.cairo_image_surface_get_stride

sr.create_image_surface_from_png = ref_func(_C.cairo_image_surface_create_from_png, C.cairo_surface_destroy)
sr.create_image_surface_from_png_stream = ref_func(_C.cairo_image_surface_create_from_png_stream, C.cairo_surface_destroy)

function M.create_recording_surface(content, x, y, w, h)

sr.ink_extents = d4out_func(C.cairo_recording_surface_ink_extents)
sr.extents = function(sr)

M.create_raster_source_pattern = function(udata, content, w, h)

patt.callback_data = getset_func(

patt.acquire = function(patt, acquire, release)
patt.snapshot = getset_func(
patt.copy = getset_func(
patt.finish = getset_func(

M.create_rgb_pattern = ref_func(C.cairo_pattern_create_rgb, C.cairo_pattern_destroy)
M.create_rgba_pattern = ref_func(C.cairo_pattern_create_rgba, C.cairo_pattern_destroy)
M.create_pattern_from_surface = ref_func(C.cairo_pattern_create_for_surface, C.cairo_pattern_destroy)
M.create_linear_pattern = ref_func(C.cairo_pattern_create_linear, C.cairo_pattern_destroy)
M.create_radial_pattern = ref_func(C.cairo_pattern_create_radial, C.cairo_pattern_destroy)
M.create_mesh_pattern = ref_func(C.cairo_pattern_create_mesh, C.cairo_pattern_destroy)

patt.ref = ref_func(C.cairo_pattern_reference, C.cairo_pattern_destroy)
patt.destroy = destroy_func(C.cairo_pattern_destroy)
patt.free = free
patt.refcount = C.cairo_pattern_get_reference_count
patt.status = C.cairo_pattern_status
patt.status_string = status_string

map('CAIRO_PATTERN_TYPE_', {
	'SOLID',
	'SURFACE',
	'LINEAR',
	'RADIAL',
	'MESH',
	'RASTER_SOURCE',
})

patt.type = getflag_func(C.cairo_pattern_get_type, 'CAIRO_PATTERN_TYPE_')

patt.add_color_stop_rgb = C.cairo_pattern_add_color_stop_rgb
patt.add_color_stop_rgb = C.cairo_pattern_add_color_stop_rgb
patt.add_color_stop_rgba = C.cairo_pattern_add_color_stop_rgba

patt.begin_patch = C.cairo_mesh_pattern_begin_patch
patt.end_patch = C.cairo_mesh_pattern_end_patch
patt.curve_to = C.cairo_mesh_pattern_curve_to
patt.line_to = C.cairo_mesh_pattern_line_to
patt.move_to = C.cairo_mesh_pattern_move_to

--TODO: combine get and set?
patt.set_control_point = C.cairo_mesh_pattern_set_control_point
patt.set_corner_color_rgb = C.cairo_mesh_pattern_set_corner_color_rgb
patt.set_corner_color_rgba = C.cairo_mesh_pattern_set_corner_color_rgba
patt.get_control_point = function(patt, patch_num, point_num)
patt.get_corner_color_rgba = function(patt, patch_num, corner_num)

patt.matrix = getset_func(mtout_getfunc(C.cairo_pattern_get_matrix), C.cairo_pattern_set_matrix)

map('CAIRO_EXTEND_', {
	'NONE',
	'REPEAT',
	'REFLECT',
	'PAD',
})

patt.extend = getset_func(C.cairo_pattern_get_extend, C.cairo_pattern_set_extend, 'CAIRO_EXTEND_')

map('CAIRO_FILTER_', {
	'FAST',
	'GOOD',
	'BEST',
	'NEAREST',
	'BILINEAR',
	'GAUSSIAN',
})

patt.filter = getset_func(C.cairo_pattern_get_filter, C.cairo_pattern_set_filter, 'CAIRO_EXTEND_')

patt.rgba = d4out_func(C.cairo_pattern_get_rgba)

patt.surface = function(patt)

patt.color_stop_rgba = function(patt, i)

patt.color_stop_count = function(patt)

patt.linear_points = function(patt)

patt.radial_circles = function(patt)

patt.patch_count = function(patt)

patt.path = C.cairo_mesh_pattern_get_path --weak ref? doc doesn't say

mt.init = C.cairo_matrix_init --TODO: check_status?
mt.init_identity = C.cairo_matrix_init_identity
mt.init_translate = C.cairo_matrix_init_translate
mt.init_scale = C.cairo_matrix_init_scale
mt.init_rotate = C.cairo_matrix_init_rotate
mt.translate = C.cairo_matrix_translate
mt.scale = C.cairo_matrix_scale
mt.rotate = C.cairo_matrix_rotate
mt.invert = C.cairo_matrix_invert --TODO: check status?
mt.multiply = C.cairo_matrix_multiply
mt.transform_distance = d2inout_func(C.cairo_matrix_transform_distance)
mt.transform_point = d2inout_func(C.cairo_matrix_transform_point)

map('CAIRO_REGION_OVERLAP_', {
	'IN',
	'OUT',
	'PART',
})

M.create_region = ref_func(C.cairo_region_create, C.cairo_region_destroy)

M.create_region_for_rectangle = function(x, y, w, h)

M.create_region_for_rectangles = ref_func(C.cairo_region_create_rectangles, C.cairo_region_destroy)

rgn.copy = ref_func(C.cairo_region_copy, C.cairo_region_destroy)
rgn.ref = C.cairo_region_reference
rgn.destroy = destroy_func(C.cairo_region_destroy)
rgn.free = free
rgn.equal = bool_func(C.cairo_region_equal)
rgn.status = C.cairo_region_status
rgn.status_string = status_string

rgn.extents = function(rgn)

rgn.num_rectangles = C.cairo_region_num_rectangles
rgn.rectangle = function(rgn, i)

rgn.is_empty = bool_func(C.cairo_region_is_empty)

function rgn.contains(x, y, w, h)

rgn.ref = ref_func(C.cairo_region_reference, C.cairo_region_destroy)
rgn.translate = C.cairo_region_translate

rgn.subtract  = op_func'region_subtract'
rgn.intersect = op_func'region_intersect'
rgn.union     = op_func'region_union'
rgn.xor       = op_func'region_xor'

M.debug_reset_static_data = C.cairo_debug_reset_static_data

--private APIs available only in our custom build

map('CAIRO_LCD_FILTER_', {
	'DEFAULT',
	'NONE',
	'INTRA_PIXEL',
	'FIR3',
	'FIR5',
})

map('CAIRO_ROUND_GLYPH_POS_', {
	'DEFAULT',
	'ON',
	'OFF',
})

fopt.lcd_filter = getset_func(

fopt.round_glyph_positions = getset_func(

--additions to context

function cr:safe_transform(mt)
function cr:rotate_around(cx, cy, angle)
function cr:scale_around(cx, cy, ...)
function cr:skew(ax, ay)
	sm:init_identity()
	sm.xy = math.tan(ax)
	sm.yx = math.tan(ay)
	cr:transform(sm)
end
function sr:apply_alpha(alpha)
function sr:bpp()
function sr:bitmap()

function sr:getpixel_function()
function sr:setpixel_function()

function cr:circle(cx, cy, r)
function cr:ellipse(cx, cy, rx, ry, rotation)
function cr:quad_curve_to(x1, y1, x2, y2)
function cr:rel_quad_curve_to(x1, y1, x2, y2)

function mt:transform(mt)
function mt:invertible(tmt)
function mt:safe_transform(self, mt)
function mt:skew(ax, ay)
function mt:rotate_around(cx, cy, angle)
function mt:scale_around(cx, cy, ...)
function mt:copy()
function mt:init_matrix(mt)

function M.create_ft_font_face(ft_face, load_flags)
face.synthesize_bold = synthesize_flag(C.CAIRO_FT_SYNTHESIZE_BOLD)
face.synthesize_oblique = synthesize_flag(C.CAIRO_FT_SYNTHESIZE_OBLIQUE)
sfont.lock_face = ref_func(_C.cairo_ft_scaled_font_lock_face, _C.cairo_ft_scaled_font_unlock_face)
]==]
