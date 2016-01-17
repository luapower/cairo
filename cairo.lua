
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
local reflect = require'ffi_reflect'
require'cairo_h'
local C = ffi.load'cairo'
local M = {C = C}

--binding automation ---------------------------------------------------------

--probing C namespace (returns nil for missing symbols)
local function sym(name) return C[name] end
local _C = setmetatable({}, {__index = function(C, k)
    return pcall(sym, k) and C[name] or nil
end})
M._C = _C

--enum bidirectional mapper
local enumvals = {} --{prefix -> {enumval -> name; name -> enumval}}
local function map(t, prefix)
	local dt = {}
	for i,v in ipairs(t) do
		local k, v = C[prefix..v], v:lower()
		dt[k] = v
		dt[v] = k
	end
	enumvals[prefix] = dt
end

--'foo' -> C.CAIRO_<PREFIX>_FOO and C.CAIRO_<PREFIX>_FOO -> 'foo' conversions
local function X(prefix, val)
	return enumvals[prefix][val]
end

--create a gc-tied constructor
local function ref_func(create, destroy)
	return create and function(...)
		return ffi.gc(create(...), destroy)
	end
end

--create a gc-untying destructor
local function destroy_func(destroy)
	return function(self)
		ffi.gc(self, nil)
		destroy(self)
	end
end

--create a flag setter
local function setflag_func(set, prefix)
	return set and function(self, flag)
		set(self, X(prefix, flag))
	end
end

--create a flag getter
local function getflag_func(get, prefix)
	return get and function(self)
		return X(prefix, get(self))
	end
end

--create a getter/setter function
local function getset_func(get, set, prefix)
	if prefix then
		local get = getflag_func(get, prefix)
		local set = setflag_func(set, prefix)
		return getset_func(get, set)
	end
	return (get or set) and function(self, val)
		if val == nil then --get val
			return get(self, val)
		else --set val
			set(self, val)
		end
	end
end

local dx1 = ffi.new'double[1]'
local dy1 = ffi.new'double[1]'
local dx2 = ffi.new'double[1]'
local dy2 = ffi.new'double[1]'

--wrap a function that returns a (x, y) tuple
local function d2out_func(func)
	return func and function(self, x, y)
		dx1[0], dy1[0] = x, y
		func(self, dx1, dy1)
		return dx1[0], dy1[0]
	end
end

local function d4out_func(func)
	return func and function(self)
		func(self, dx1, dy1, dx2, dy2)
		return dx1[0], dy1[0], dx2[0], dy2[0]
	end
end

-- int -> bool
local function bool_func(f)
	return f and function(...)
		return f(...) ~= 0
	end
end

--return a wrapping function that returns a struct
local function structout_func(ctype)
	return function(func)
		return func and function(self, out)
			out = out or ffi.new(ctype)
			func(cr, out)
			return out
		end
	end
end
mtout_func = structout_func'cairo_matrix_t'
foptout_func = structout_func'cairo_font_options_t'

--library --------------------------------------------------------------------

M.version = C.cairo_version

function M.version_string()
	return ffi.string(C.cairo_version_string())
end

map('CAIRO_STATUS_', {
	'SUCCESS',
	'NO_MEMORY',
	'INVALID_RESTORE',
	'INVALID_POP_GROUP',
	'NO_CURRENT_POINT',
	'INVALID_MATRIX',
	'INVALID_STATUS',
	'NULL_POINTER',
	'INVALID_STRING',
	'INVALID_PATH_DATA',
	'READ_ERROR',
	'WRITE_ERROR',
	'SURFACE_FINISHED',
	'SURFACE_TYPE_MISMATCH',
	'PATTERN_TYPE_MISMATCH',
	'INVALID_CONTENT',
	'INVALID_FORMAT',
	'INVALID_VISUAL',
	'FILE_NOT_FOUND',
	'INVALID_DASH',
	'INVALID_DSC_COMMENT',
	'INVALID_INDEX',
	'CLIP_NOT_REPRESENTABLE',
	'TEMP_FILE_ERROR',
	'INVALID_STRIDE',
	'FONT_TYPE_MISMATCH',
	'USER_FONT_IMMUTABLE',
	'USER_FONT_ERROR',
	'NEGATIVE_COUNT',
	'INVALID_CLUSTERS',
	'INVALID_SLANT',
	'INVALID_WEIGHT',
	'INVALID_SIZE',
	'USER_FONT_NOT_IMPLEMENTED',
	'DEVICE_TYPE_MISMATCH',
	'DEVICE_ERROR',
	'INVALID_MESH_CONSTRUCTION',
	'DEVICE_FINISHED',
	'LAST_STATUS',
})

map('CAIRO_CONTENT_', {
	'COLOR',
	'ALPHA',
	'COLOR_ALPHA',
})

map('CAIRO_FORMAT_', {
	'INVALID',
	'ARGB32',
	'RGB24',
	'A8',
	'A1',
	'RGB16_565',
	'RGB30',
})

M.create = ref_func(C.cairo_create, C.cairo_destroy)
M.reference = ref_func(C.cairo_reference, C.cairo_destroy)
M.destroy = destroy_func(C.cairo_destroy)
M.get_reference_count = C.cairo_get_reference_count
M.save = C.cairo_save
M.restore = C.cairo_restore
M.push_group = C.cairo_push_group
M.push_group_with_content = setflag_func(C.cairo_push_group_with_content, 'CAIRO_CONTENT_')
M.pop_group = ref_func(C.cairo_pop_group, C.cairo_pattern_destroy)
M.pop_group_to_source = C.cairo_pop_group_to_source

map('CAIRO_OPERATOR_', {
	'CLEAR',
	'SOURCE',
	'OVER',
	'IN',
	'OUT',
	'ATOP',
	'DEST',
	'DEST_OVER',
	'DEST_IN',
	'DEST_OUT',
	'DEST_ATOP',
	'XOR',
	'ADD',
	'SATURATE',
	'MULTIPLY',
	'SCREEN',
	'OVERLAY',
	'DARKEN',
	'LIGHTEN',
	'COLOR_DODGE',
	'COLOR_BURN',
	'HARD_LIGHT',
	'SOFT_LIGHT',
	'DIFFERENCE',
	'EXCLUSION',
	'HSL_HUE',
	'HSL_SATURATION',
	'HSL_COLOR',
	'HSL_LUMINOSITY',
})

M.operator = getset_func(C.cairo_get_operator, C.cairo_set_operator, 'CAIRO_OPERATOR_')
M.source = getset_func(C.cairo_get_source, C.cairo_set_source)
M.source_rgb = C.cairo_set_source_rgb
M.source_rgba = C.cairo_set_source_rgba
M.source_surface = C.cairo_set_source_surface
M.tolerance = getset_func(C.cairo_get_tolerance, C.cairo_set_tolerance)

map('CAIRO_ANTIALIAS_', {
	'DEFAULT',
	'NONE',
	'GRAY',
	'SUBPIXEL',
	'FAST',
	'GOOD',
	'BEST',
})

M.antialias = getset_func(C.cairo_get_antialias, C.cairo_set_antialias, 'CAIRO_ANTIALIAS_')

map('CAIRO_FILL_RULE_', {
	'WINDING',
	'EVEN_ODD',
})

M.fill_rule = getset_func(C.cairo_get_fill_rule, C.cairo_set_fill_rule, 'CAIRO_FILL_RULE_')

M.line_width = getset_func(C.cairo_get_line_width, C.cairo_set_line_width)

map('CAIRO_LINE_CAP_', {
	'BUTT',
	'ROUND',
	'SQUARE',
})

M.line_cap = getset_func(C.cairo_get_line_cap, C.cairo_set_line_cap, 'CAIRO_LINE_CAP_')

map('CAIRO_LINE_JOIN_', {
	'MITER',
	'ROUND',
	'BEVEL',
})

M.line_join = getset_func(C.cairo_get_line_join, C.cairo_set_line_join, 'CAIRO_LINE_JOIN_')

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

M.miter_limit = getset_func(C.cairo_get_miter_limit, C.cairo_set_miter_limit)

M.translate = C.cairo_translate
M.scale = C.cairo_scale
M.rotate = C.cairo_rotate
M.transform = C.cairo_transform
M.set_matrix = C.cairo_set_matrix
M.identity_matrix = C.cairo_identity_matrix

M.user_to_device          = d2out_func(C.cairo_user_to_device)
M.user_to_device_distance = d2out_func(C.cairo_user_to_device_distance)
M.device_to_user          = d2out_func(C.cairo_device_to_user)
M.device_to_user_distance = d2out_func(C.cairo_device_to_user_distance)

M.new_path = C.cairo_new_path
M.move_to = C.cairo_move_to
M.new_sub_path = C.cairo_new_sub_path
M.line_to = C.cairo_line_to
M.curve_to = C.cairo_curve_to
M.arc = C.cairo_arc
M.arc_negative = C.cairo_arc_negative
M.rel_move_to = C.cairo_rel_move_to
M.rel_line_to = C.cairo_rel_line_to
M.rel_curve_to = C.cairo_rel_curve_to
M.rectangle = C.cairo_rectangle
M.close_path = C.cairo_close_path
M.path_extents = d4out_func(C.cairo_path_extents)
M.paint = C.cairo_paint
M.paint_with_alpha = C.cairo_paint_with_alpha
M.mask = C.cairo_mask
M.mask_surface = C.cairo_mask_surface
M.stroke = C.cairo_stroke
M.stroke_preserve = C.cairo_stroke_preserve
M.fill = C.cairo_fill
M.fill_preserve = C.cairo_fill_preserve

M.copy_page = C.cairo_copy_page
M.show_page = C.cairo_show_page


M.in_stroke = bool_func(C.cairo_in_stroke)
M.in_fill = bool_func(C.cairo_in_fill)
M.in_clip = bool_func(C.cairo_in_clip)

M.stroke_extents = d4out_func(C.cairo_stroke_extents)
M.fill_extents = d4out_func(C.cairo_fill_extents)
M.reset_clip = C.cairo_reset_clip
M.clip = C.cairo_clip
M.clip_preserve = C.cairo_clip_preserve
M.clip_extents = d4out_func(C.cairo_clip_extents)
M.copy_clip_rectangle_list = ref_func(C.cairo_copy_clip_rectangle_list, C.cairo_rectangle_list_destroy)
M.rectangle_list_destroy = destroy_func(C.cairo_rectangle_list_destroy)

M.glyph_allocate = ref_func(C.cairo_glyph_allocate, C.cairo_glyph_free)
M.glyph_free = destroy_func(C.cairo_glyph_free)
M.text_cluster_allocate = ref_func(C.cairo_text_cluster_allocate, C.cairo_text_cluster_free)
M.text_cluster_free = destroy_func(C.cairo_text_cluster_free)

map('CAIRO_TEXT_CLUSTER_FLAG_', {
	'CAIRO_TEXT_CLUSTER_FLAG_BACKWARD',
})

map('CAIRO_FONT_SLANT_', {
	'NORMAL',
	'ITALIC',
	'OBLIQUE',
})

map('CAIRO_FONT_WEIGHT_', {
	'NORMAL',
	'BOLD',
})

map('CAIRO_SUBPIXEL_ORDER_', {
	'DEFAULT',
	'RGB',
	'BGR',
	'VRGB',
	'VBGR',
})

map('CAIRO_HINT_STYLE_', {
	'DEFAULT',
	'NONE',
	'SLIGHT',
	'MEDIUM',
	'FULL',
})

map('CAIRO_HINT_METRICS_', {
	'DEFAULT',
	'OFF',
	'ON',
})

M.font_options_create = ref_func(C.cairo_font_options_create, C.cairo_font_options_destroy)
M.font_options_copy = ref_func(C.cairo_font_options_copy, C.cairo_font_options_destroy)
M.font_options_destroy = destroy_func(C.cairo_font_options_destroy)
M.font_options_status = C.cairo_font_options_status
M.font_options_merge = C.cairo_font_options_merge
M.font_options_equal = bool_func(C.cairo_font_options_equal)
M.font_options_hash = C.cairo_font_options_hash
M.font_options_antialias = getset_func(C.cairo_font_options_get_antialias, C.cairo_font_options_set_antialias, 'CAIRO_ANTIALIAS_')
M.font_options_set_subpixel_order = getset_func(C.cairo_font_options_get_subpixel_order, C.cairo_font_options_set_subpixel_order , 'CAIRO_SUBPIXEL_ORDER_')
M.font_options_set_hint_style = getset_func(C.cairo_font_options_get_hint_style, C.cairo_font_options_set_hint_style, 'CAIRO_HINT_STYLE_')
M.font_options_set_hint_metrics = getset_func(C.cairo_font_options_get_hint_metrics, C.cairo_font_options_set_hint_metrics, 'CAIRO_HINT_METRICS_')

function M.select_font_face(cr, family, slant, weight)
	C.cairo_select_font_face(cr, family,
		X('CAIRO_FONT_SLANT_', slant),
		X('CAIRO_FONT_WEIGHT_', weight))
end

M.font_size = C.cairo_set_font_size
M.font_matrix = getset_func(mtout_func(C.cairo_get_font_matrix), C.cairo_set_font_matrix)
M.font_options = getset_func(foptout_func(C.cairo_get_font_options), C.cairo_set_font_options)
M.font_face = getset_func(C.cairo_get_font_face, C.cairo_set_font_face) --TODO: ref?
M.scaled_font = getset_func(C.cairo_get_scaled_font, C.cairo_set_scaled_font) --TODO: ref?
M.show_text = C.cairo_show_text
M.show_glyphs = C.cairo_show_glyphs
M.show_text_glyphs = function(cr, s, slen, glyphs, num_glyphs, clusters, num_clusters, cluster_flags)
	C.cairo_show_text_glyphs(cr, s, slen, glyphs, num_glyphs, clusters, num_clusters, cluster_flags)
end
   const char *utf8,
   int utf8_len,
   const cairo_glyph_t *glyphs,
   int num_glyphs,
   const cairo_text_cluster_t *clusters,
   int num_clusters,
   cairo_text_cluster_flags_t cluster_flags);
 void
cairo_text_path (cairo_t *cr, const char *utf8);
 void
cairo_glyph_path (cairo_t *cr, const cairo_glyph_t *glyphs, int num_glyphs);
 void
cairo_text_extents (cairo_t *cr,
      const char *utf8,
      cairo_text_extents_t *extents);
 void
cairo_glyph_extents (cairo_t *cr,
       const cairo_glyph_t *glyphs,
       int num_glyphs,
       cairo_text_extents_t *extents);
 void
cairo_font_extents (cairo_t *cr,
      cairo_font_extents_t *extents);
 cairo_font_face_t *
cairo_font_face_reference (cairo_font_face_t *font_face);
 void
cairo_font_face_destroy (cairo_font_face_t *font_face);
 unsigned int
cairo_font_face_get_reference_count (cairo_font_face_t *font_face);
 cairo_status_t
cairo_font_face_status (cairo_font_face_t *font_face);
typedef enum _cairo_font_type {
    CAIRO_FONT_TYPE_TOY,
    CAIRO_FONT_TYPE_FT,
    CAIRO_FONT_TYPE_WIN32,
    CAIRO_FONT_TYPE_QUARTZ,
    CAIRO_FONT_TYPE_USER
} cairo_font_type_t;
 cairo_font_type_t
cairo_font_face_get_type (cairo_font_face_t *font_face);
 void *
cairo_font_face_get_user_data (cairo_font_face_t *font_face,
          const cairo_user_data_key_t *key);
 cairo_status_t
cairo_font_face_set_user_data (cairo_font_face_t *font_face,
          const cairo_user_data_key_t *key,
          void *user_data,
          cairo_destroy_func_t destroy);
 cairo_scaled_font_t *
cairo_scaled_font_create (cairo_font_face_t *font_face,
     const cairo_matrix_t *font_matrix,
     const cairo_matrix_t *ctm,
     const cairo_font_options_t *options);
 cairo_scaled_font_t *
cairo_scaled_font_reference (cairo_scaled_font_t *scaled_font);
 void
cairo_scaled_font_destroy (cairo_scaled_font_t *scaled_font);
 unsigned int
cairo_scaled_font_get_reference_count (cairo_scaled_font_t *scaled_font);
 cairo_status_t
cairo_scaled_font_status (cairo_scaled_font_t *scaled_font);
 cairo_font_type_t
cairo_scaled_font_get_type (cairo_scaled_font_t *scaled_font);
 void *
cairo_scaled_font_get_user_data (cairo_scaled_font_t *scaled_font,
     const cairo_user_data_key_t *key);
 cairo_status_t
cairo_scaled_font_set_user_data (cairo_scaled_font_t *scaled_font,
     const cairo_user_data_key_t *key,
     void *user_data,
     cairo_destroy_func_t destroy);
 void
cairo_scaled_font_extents (cairo_scaled_font_t *scaled_font,
      cairo_font_extents_t *extents);
 void
cairo_scaled_font_text_extents (cairo_scaled_font_t *scaled_font,
    const char *utf8,
    cairo_text_extents_t *extents);
 void
cairo_scaled_font_glyph_extents (cairo_scaled_font_t *scaled_font,
     const cairo_glyph_t *glyphs,
     int num_glyphs,
     cairo_text_extents_t *extents);
 cairo_status_t
cairo_scaled_font_text_to_glyphs (cairo_scaled_font_t *scaled_font,
      double x,
      double y,
      const char *utf8,
      int utf8_len,
      cairo_glyph_t **glyphs,
      int *num_glyphs,
      cairo_text_cluster_t **clusters,
      int *num_clusters,
      cairo_text_cluster_flags_t *cluster_flags);
 cairo_font_face_t *
cairo_scaled_font_get_font_face (cairo_scaled_font_t *scaled_font);
 void
cairo_scaled_font_get_font_matrix (cairo_scaled_font_t *scaled_font,
       cairo_matrix_t *font_matrix);
 void
cairo_scaled_font_get_ctm (cairo_scaled_font_t *scaled_font,
      cairo_matrix_t *ctm);
 void
cairo_scaled_font_get_scale_matrix (cairo_scaled_font_t *scaled_font,
        cairo_matrix_t *scale_matrix);
 void
cairo_scaled_font_get_font_options (cairo_scaled_font_t *scaled_font,
        cairo_font_options_t *options);
 cairo_font_face_t *
cairo_toy_font_face_create (const char *family,
       cairo_font_slant_t slant,
       cairo_font_weight_t weight);
 const char *
cairo_toy_font_face_get_family (cairo_font_face_t *font_face);
 cairo_font_slant_t
cairo_toy_font_face_get_slant (cairo_font_face_t *font_face);
 cairo_font_weight_t
cairo_toy_font_face_get_weight (cairo_font_face_t *font_face);
 cairo_font_face_t *
cairo_user_font_face_create (void);
typedef cairo_status_t (*cairo_user_scaled_font_init_func_t) (cairo_scaled_font_t *scaled_font,
             cairo_t *cr,
             cairo_font_extents_t *extents);
typedef cairo_status_t (*cairo_user_scaled_font_render_glyph_func_t) (cairo_scaled_font_t *scaled_font,
              unsigned long glyph,
              cairo_t *cr,
              cairo_text_extents_t *extents);
typedef cairo_status_t (*cairo_user_scaled_font_text_to_glyphs_func_t) (cairo_scaled_font_t *scaled_font,
         const char *utf8,
         int utf8_len,
         cairo_glyph_t **glyphs,
         int *num_glyphs,
         cairo_text_cluster_t **clusters,
         int *num_clusters,
         cairo_text_cluster_flags_t *cluster_flags);
typedef cairo_status_t (*cairo_user_scaled_font_unicode_to_glyph_func_t) (cairo_scaled_font_t *scaled_font,
           unsigned long unicode,
           unsigned long *glyph_index);
 void
cairo_user_font_face_set_init_func (cairo_font_face_t *font_face,
        cairo_user_scaled_font_init_func_t init_func);
 void
cairo_user_font_face_set_render_glyph_func (cairo_font_face_t *font_face,
         cairo_user_scaled_font_render_glyph_func_t render_glyph_func);
 void
cairo_user_font_face_set_text_to_glyphs_func (cairo_font_face_t *font_face,
           cairo_user_scaled_font_text_to_glyphs_func_t text_to_glyphs_func);
 void
cairo_user_font_face_set_unicode_to_glyph_func (cairo_font_face_t *font_face,
             cairo_user_scaled_font_unicode_to_glyph_func_t unicode_to_glyph_func);
 cairo_user_scaled_font_init_func_t
cairo_user_font_face_get_init_func (cairo_font_face_t *font_face);
 cairo_user_scaled_font_render_glyph_func_t
cairo_user_font_face_get_render_glyph_func (cairo_font_face_t *font_face);
 cairo_user_scaled_font_text_to_glyphs_func_t
cairo_user_font_face_get_text_to_glyphs_func (cairo_font_face_t *font_face);
 cairo_user_scaled_font_unicode_to_glyph_func_t
cairo_user_font_face_get_unicode_to_glyph_func (cairo_font_face_t *font_face);
 cairo_operator_t
cairo_get_operator (cairo_t *cr);
cairo_antialias_t
cairo_get_antialias (cairo_t *cr);
 cairo_bool_t
cairo_has_current_point (cairo_t *cr);
 void
cairo_get_current_point (cairo_t *cr, double *x, double *y);
 cairo_fill_rule_t
cairo_get_fill_rule (cairo_t *cr);
 double
cairo_get_line_width (cairo_t *cr);
 cairo_line_cap_t
cairo_get_line_cap (cairo_t *cr);
 cairo_line_join_t
cairo_get_line_join (cairo_t *cr);
 double
cairo_get_miter_limit (cairo_t *cr);
 int
cairo_get_dash_count (cairo_t *cr);
 void
cairo_get_dash (cairo_t *cr, double *dashes, double *offset);
 void
cairo_get_matrix (cairo_t *cr, cairo_matrix_t *matrix);
 cairo_surface_t *
cairo_get_target (cairo_t *cr);
 cairo_surface_t *
cairo_get_group_target (cairo_t *cr);
typedef enum _cairo_path_data_type {
    CAIRO_PATH_MOVE_TO,
    CAIRO_PATH_LINE_TO,
    CAIRO_PATH_CURVE_TO,
    CAIRO_PATH_CLOSE_PATH
} cairo_path_data_type_t;
typedef union _cairo_path_data_t cairo_path_data_t;
union _cairo_path_data_t {
    struct {
 cairo_path_data_type_t type;
 int length;
    } header;
    struct {
 double x, y;
    } point;
};
typedef struct cairo_path {
    cairo_status_t status;
    cairo_path_data_t *data;
    int num_data;
} cairo_path_t;
 cairo_path_t *
cairo_copy_path (cairo_t *cr);
 cairo_path_t *
cairo_copy_path_flat (cairo_t *cr);
 void
cairo_append_path (cairo_t *cr,
     const cairo_path_t *path);
 void
cairo_path_destroy (cairo_path_t *path);
 cairo_status_t
cairo_status (cairo_t *cr);
 const char *
cairo_status_to_string (cairo_status_t status);
 cairo_device_t *
cairo_device_reference (cairo_device_t *device);
typedef enum _cairo_device_type {
    CAIRO_DEVICE_TYPE_DRM,
    CAIRO_DEVICE_TYPE_GL,
    CAIRO_DEVICE_TYPE_SCRIPT,
    CAIRO_DEVICE_TYPE_XCB,
    CAIRO_DEVICE_TYPE_XLIB,
    CAIRO_DEVICE_TYPE_XML,
    CAIRO_DEVICE_TYPE_COGL,
    CAIRO_DEVICE_TYPE_WIN32,
    CAIRO_DEVICE_TYPE_INVALID = -1
} cairo_device_type_t;
 cairo_device_type_t
cairo_device_get_type (cairo_device_t *device);
 cairo_status_t
cairo_device_status (cairo_device_t *device);
 cairo_status_t
cairo_device_acquire (cairo_device_t *device);
 void
cairo_device_release (cairo_device_t *device);
 void
cairo_device_flush (cairo_device_t *device);
 void
cairo_device_finish (cairo_device_t *device);
 void
cairo_device_destroy (cairo_device_t *device);
 unsigned int
cairo_device_get_reference_count (cairo_device_t *device);
 void *
cairo_device_get_user_data (cairo_device_t *device,
       const cairo_user_data_key_t *key);
 cairo_status_t
cairo_device_set_user_data (cairo_device_t *device,
       const cairo_user_data_key_t *key,
       void *user_data,
       cairo_destroy_func_t destroy);
 cairo_surface_t *
cairo_surface_create_similar (cairo_surface_t *other,
         cairo_content_t content,
         int width,
         int height);
 cairo_surface_t *
cairo_surface_create_similar_image (cairo_surface_t *other,
        cairo_format_t format,
        int width,
        int height);
 cairo_surface_t *
cairo_surface_map_to_image (cairo_surface_t *surface,
       const cairo_rectangle_int_t *extents);
 void
cairo_surface_unmap_image (cairo_surface_t *surface,
      cairo_surface_t *image);
 cairo_surface_t *
cairo_surface_create_for_rectangle (cairo_surface_t *target,
                                    double x,
                                    double y,
                                    double width,
                                    double height);
typedef enum _cairo_surface_observer {
 CAIRO_SURFACE_OBSERVER_NORMAL = 0,
 CAIRO_SURFACE_OBSERVER_RECORD_OPERATIONS = 0x1
} cairo_surface_observer_mode_t;
 cairo_surface_t *
cairo_surface_create_observer (cairo_surface_t *target,
          cairo_surface_observer_mode_t mode);
typedef void (*cairo_surface_observer_callback_t) (cairo_surface_t *observer,
         cairo_surface_t *target,
         void *data);
 cairo_status_t
cairo_surface_observer_add_paint_callback (cairo_surface_t *abstract_surface,
        cairo_surface_observer_callback_t func,
        void *data);
 cairo_status_t
cairo_surface_observer_add_mask_callback (cairo_surface_t *abstract_surface,
       cairo_surface_observer_callback_t func,
       void *data);
 cairo_status_t
cairo_surface_observer_add_fill_callback (cairo_surface_t *abstract_surface,
       cairo_surface_observer_callback_t func,
       void *data);
 cairo_status_t
cairo_surface_observer_add_stroke_callback (cairo_surface_t *abstract_surface,
         cairo_surface_observer_callback_t func,
         void *data);
 cairo_status_t
cairo_surface_observer_add_glyphs_callback (cairo_surface_t *abstract_surface,
         cairo_surface_observer_callback_t func,
         void *data);
 cairo_status_t
cairo_surface_observer_add_flush_callback (cairo_surface_t *abstract_surface,
        cairo_surface_observer_callback_t func,
        void *data);
 cairo_status_t
cairo_surface_observer_add_finish_callback (cairo_surface_t *abstract_surface,
         cairo_surface_observer_callback_t func,
         void *data);
 cairo_status_t
cairo_surface_observer_print (cairo_surface_t *surface,
         cairo_write_func_t write_func,
         void *closure);
 double
cairo_surface_observer_elapsed (cairo_surface_t *surface);
 cairo_status_t
cairo_device_observer_print (cairo_device_t *device,
        cairo_write_func_t write_func,
        void *closure);
 double
cairo_device_observer_elapsed (cairo_device_t *device);
 double
cairo_device_observer_paint_elapsed (cairo_device_t *device);
 double
cairo_device_observer_mask_elapsed (cairo_device_t *device);
 double
cairo_device_observer_fill_elapsed (cairo_device_t *device);
 double
cairo_device_observer_stroke_elapsed (cairo_device_t *device);
 double
cairo_device_observer_glyphs_elapsed (cairo_device_t *device);
 cairo_surface_t *
cairo_surface_reference (cairo_surface_t *surface);
 void
cairo_surface_finish (cairo_surface_t *surface);
 void
cairo_surface_destroy (cairo_surface_t *surface);
 cairo_device_t *
cairo_surface_get_device (cairo_surface_t *surface);
 unsigned int
cairo_surface_get_reference_count (cairo_surface_t *surface);
 cairo_status_t
cairo_surface_status (cairo_surface_t *surface);
typedef enum _cairo_surface_type {
    CAIRO_SURFACE_TYPE_IMAGE,
    CAIRO_SURFACE_TYPE_PDF,
    CAIRO_SURFACE_TYPE_PS,
    CAIRO_SURFACE_TYPE_XLIB,
    CAIRO_SURFACE_TYPE_XCB,
    CAIRO_SURFACE_TYPE_GLITZ,
    CAIRO_SURFACE_TYPE_QUARTZ,
    CAIRO_SURFACE_TYPE_WIN32,
    CAIRO_SURFACE_TYPE_BEOS,
    CAIRO_SURFACE_TYPE_DIRECTFB,
    CAIRO_SURFACE_TYPE_SVG,
    CAIRO_SURFACE_TYPE_OS2,
    CAIRO_SURFACE_TYPE_WIN32_PRINTING,
    CAIRO_SURFACE_TYPE_QUARTZ_IMAGE,
    CAIRO_SURFACE_TYPE_SCRIPT,
    CAIRO_SURFACE_TYPE_QT,
    CAIRO_SURFACE_TYPE_RECORDING,
    CAIRO_SURFACE_TYPE_VG,
    CAIRO_SURFACE_TYPE_GL,
    CAIRO_SURFACE_TYPE_DRM,
    CAIRO_SURFACE_TYPE_TEE,
    CAIRO_SURFACE_TYPE_XML,
    CAIRO_SURFACE_TYPE_SKIA,
    CAIRO_SURFACE_TYPE_SUBSURFACE,
    CAIRO_SURFACE_TYPE_COGL
} cairo_surface_type_t;
 cairo_surface_type_t
cairo_surface_get_type (cairo_surface_t *surface);
 cairo_content_t
cairo_surface_get_content (cairo_surface_t *surface);
 cairo_status_t
cairo_surface_write_to_png (cairo_surface_t *surface,
       const char *filename);
 cairo_status_t
cairo_surface_write_to_png_stream (cairo_surface_t *surface,
       cairo_write_func_t write_func,
       void *closure);
 void *
cairo_surface_get_user_data (cairo_surface_t *surface,
        const cairo_user_data_key_t *key);
 cairo_status_t
cairo_surface_set_user_data (cairo_surface_t *surface,
        const cairo_user_data_key_t *key,
        void *user_data,
        cairo_destroy_func_t destroy);
 void
cairo_surface_get_mime_data (cairo_surface_t *surface,
                             const char *mime_type,
                             const void **data,
                             unsigned long *length);
 cairo_status_t
cairo_surface_set_mime_data (cairo_surface_t *surface,
                             const char *mime_type,
                             const void *data,
                             unsigned long length,
        cairo_destroy_func_t destroy,
        void *closure);
 cairo_bool_t
cairo_surface_supports_mime_type (cairo_surface_t *surface,
      const char *mime_type);
 void
cairo_surface_get_font_options (cairo_surface_t *surface,
    cairo_font_options_t *options);
 void
cairo_surface_flush (cairo_surface_t *surface);
 void
cairo_surface_mark_dirty (cairo_surface_t *surface);
 void
cairo_surface_mark_dirty_rectangle (cairo_surface_t *surface,
        int x,
        int y,
        int width,
        int height);
 void
cairo_surface_set_device_offset (cairo_surface_t *surface,
     double x_offset,
     double y_offset);
 void
cairo_surface_get_device_offset (cairo_surface_t *surface,
     double *x_offset,
     double *y_offset);
 void
cairo_surface_set_fallback_resolution (cairo_surface_t *surface,
           double x_pixels_per_inch,
           double y_pixels_per_inch);
 void
cairo_surface_get_fallback_resolution (cairo_surface_t *surface,
           double *x_pixels_per_inch,
           double *y_pixels_per_inch);
 void
cairo_surface_copy_page (cairo_surface_t *surface);
 void
cairo_surface_show_page (cairo_surface_t *surface);
 cairo_bool_t
cairo_surface_has_show_text_glyphs (cairo_surface_t *surface);
 cairo_surface_t *
cairo_image_surface_create (cairo_format_t format,
       int width,
       int height);
 int
cairo_format_stride_for_width (cairo_format_t format,
          int width);
 cairo_surface_t *
cairo_image_surface_create_for_data (void *data,
         cairo_format_t format,
         int width,
         int height,
         int stride);
 void *
cairo_image_surface_get_data (cairo_surface_t *surface);
 cairo_format_t
cairo_image_surface_get_format (cairo_surface_t *surface);
 int
cairo_image_surface_get_width (cairo_surface_t *surface);
 int
cairo_image_surface_get_height (cairo_surface_t *surface);
 int
cairo_image_surface_get_stride (cairo_surface_t *surface);
 cairo_surface_t *
cairo_image_surface_create_from_png (const char *filename);
 cairo_surface_t *
cairo_image_surface_create_from_png_stream (cairo_read_func_t read_func,
         void *closure);
 cairo_surface_t *
cairo_recording_surface_create (cairo_content_t content,
                                const cairo_rectangle_t *extents);
 void
cairo_recording_surface_ink_extents (cairo_surface_t *surface,
                                     double *x0,
                                     double *y0,
                                     double *width,
                                     double *height);
 cairo_bool_t
cairo_recording_surface_get_extents (cairo_surface_t *surface,
         cairo_rectangle_t *extents);
typedef cairo_surface_t *
(*cairo_raster_source_acquire_func_t) (cairo_pattern_t *pattern,
           void *callback_data,
           cairo_surface_t *target,
           const cairo_rectangle_int_t *extents);
typedef void
(*cairo_raster_source_release_func_t) (cairo_pattern_t *pattern,
           void *callback_data,
           cairo_surface_t *surface);
typedef cairo_status_t
(*cairo_raster_source_snapshot_func_t) (cairo_pattern_t *pattern,
     void *callback_data);
typedef cairo_status_t
(*cairo_raster_source_copy_func_t) (cairo_pattern_t *pattern,
        void *callback_data,
        const cairo_pattern_t *other);
typedef void
(*cairo_raster_source_finish_func_t) (cairo_pattern_t *pattern,
          void *callback_data);
 cairo_pattern_t *
cairo_pattern_create_raster_source (void *user_data,
        cairo_content_t content,
        int width, int height);
 void
cairo_raster_source_pattern_set_callback_data (cairo_pattern_t *pattern,
            void *data);
 void *
cairo_raster_source_pattern_get_callback_data (cairo_pattern_t *pattern);
 void
cairo_raster_source_pattern_set_acquire (cairo_pattern_t *pattern,
      cairo_raster_source_acquire_func_t acquire,
      cairo_raster_source_release_func_t release);
 void
cairo_raster_source_pattern_get_acquire (cairo_pattern_t *pattern,
      cairo_raster_source_acquire_func_t *acquire,
      cairo_raster_source_release_func_t *release);
 void
cairo_raster_source_pattern_set_snapshot (cairo_pattern_t *pattern,
       cairo_raster_source_snapshot_func_t snapshot);
 cairo_raster_source_snapshot_func_t
cairo_raster_source_pattern_get_snapshot (cairo_pattern_t *pattern);
 void
cairo_raster_source_pattern_set_copy (cairo_pattern_t *pattern,
          cairo_raster_source_copy_func_t copy);
 cairo_raster_source_copy_func_t
cairo_raster_source_pattern_get_copy (cairo_pattern_t *pattern);
 void
cairo_raster_source_pattern_set_finish (cairo_pattern_t *pattern,
     cairo_raster_source_finish_func_t finish);
 cairo_raster_source_finish_func_t
cairo_raster_source_pattern_get_finish (cairo_pattern_t *pattern);
 cairo_pattern_t *
cairo_pattern_create_rgb (double red, double green, double blue);
 cairo_pattern_t *
cairo_pattern_create_rgba (double red, double green, double blue,
      double alpha);
 cairo_pattern_t *
cairo_pattern_create_for_surface (cairo_surface_t *surface);
 cairo_pattern_t *
cairo_pattern_create_linear (double x0, double y0,
        double x1, double y1);
 cairo_pattern_t *
cairo_pattern_create_radial (double cx0, double cy0, double radius0,
        double cx1, double cy1, double radius1);
 cairo_pattern_t *
cairo_pattern_create_mesh (void);
 cairo_pattern_t *
cairo_pattern_reference (cairo_pattern_t *pattern);
 void
cairo_pattern_destroy (cairo_pattern_t *pattern);
 unsigned int
cairo_pattern_get_reference_count (cairo_pattern_t *pattern);
 cairo_status_t
cairo_pattern_status (cairo_pattern_t *pattern);
 void *
cairo_pattern_get_user_data (cairo_pattern_t *pattern,
        const cairo_user_data_key_t *key);
 cairo_status_t
cairo_pattern_set_user_data (cairo_pattern_t *pattern,
        const cairo_user_data_key_t *key,
        void *user_data,
        cairo_destroy_func_t destroy);
typedef enum _cairo_pattern_type {
    CAIRO_PATTERN_TYPE_SOLID,
    CAIRO_PATTERN_TYPE_SURFACE,
    CAIRO_PATTERN_TYPE_LINEAR,
    CAIRO_PATTERN_TYPE_RADIAL,
    CAIRO_PATTERN_TYPE_MESH,
    CAIRO_PATTERN_TYPE_RASTER_SOURCE
} cairo_pattern_type_t;
 cairo_pattern_type_t
cairo_pattern_get_type (cairo_pattern_t *pattern);
 void
cairo_pattern_add_color_stop_rgb (cairo_pattern_t *pattern,
      double offset,
      double red, double green, double blue);
 void
cairo_pattern_add_color_stop_rgba (cairo_pattern_t *pattern,
       double offset,
       double red, double green, double blue,
       double alpha);
 void
cairo_mesh_pattern_begin_patch (cairo_pattern_t *pattern);
 void
cairo_mesh_pattern_end_patch (cairo_pattern_t *pattern);
 void
cairo_mesh_pattern_curve_to (cairo_pattern_t *pattern,
        double x1, double y1,
        double x2, double y2,
        double x3, double y3);
 void
cairo_mesh_pattern_line_to (cairo_pattern_t *pattern,
       double x, double y);
 void
cairo_mesh_pattern_move_to (cairo_pattern_t *pattern,
       double x, double y);
 void
cairo_mesh_pattern_set_control_point (cairo_pattern_t *pattern,
          unsigned int point_num,
          double x, double y);
 void
cairo_mesh_pattern_set_corner_color_rgb (cairo_pattern_t *pattern,
      unsigned int corner_num,
      double red, double green, double blue);
 void
cairo_mesh_pattern_set_corner_color_rgba (cairo_pattern_t *pattern,
       unsigned int corner_num,
       double red, double green, double blue,
       double alpha);
 void
cairo_pattern_set_matrix (cairo_pattern_t *pattern,
     const cairo_matrix_t *matrix);
 void
cairo_pattern_get_matrix (cairo_pattern_t *pattern,
     cairo_matrix_t *matrix);
typedef enum _cairo_extend {
    CAIRO_EXTEND_NONE,
    CAIRO_EXTEND_REPEAT,
    CAIRO_EXTEND_REFLECT,
    CAIRO_EXTEND_PAD
} cairo_extend_t;
 void
cairo_pattern_set_extend (cairo_pattern_t *pattern, cairo_extend_t extend);
 cairo_extend_t
cairo_pattern_get_extend (cairo_pattern_t *pattern);
typedef enum _cairo_filter {
    CAIRO_FILTER_FAST,
    CAIRO_FILTER_GOOD,
    CAIRO_FILTER_BEST,
    CAIRO_FILTER_NEAREST,
    CAIRO_FILTER_BILINEAR,
    CAIRO_FILTER_GAUSSIAN
} cairo_filter_t;
 void
cairo_pattern_set_filter (cairo_pattern_t *pattern, cairo_filter_t filter);
 cairo_filter_t
cairo_pattern_get_filter (cairo_pattern_t *pattern);
 cairo_status_t
cairo_pattern_get_rgba (cairo_pattern_t *pattern,
   double *red, double *green,
   double *blue, double *alpha);
 cairo_status_t
cairo_pattern_get_surface (cairo_pattern_t *pattern,
      cairo_surface_t **surface);
 cairo_status_t
cairo_pattern_get_color_stop_rgba (cairo_pattern_t *pattern,
       int index, double *offset,
       double *red, double *green,
       double *blue, double *alpha);
 cairo_status_t
cairo_pattern_get_color_stop_count (cairo_pattern_t *pattern,
        int *count);
 cairo_status_t
cairo_pattern_get_linear_points (cairo_pattern_t *pattern,
     double *x0, double *y0,
     double *x1, double *y1);
 cairo_status_t
cairo_pattern_get_radial_circles (cairo_pattern_t *pattern,
      double *x0, double *y0, double *r0,
      double *x1, double *y1, double *r1);
 cairo_status_t
cairo_mesh_pattern_get_patch_count (cairo_pattern_t *pattern,
        unsigned int *count);
 cairo_path_t *
cairo_mesh_pattern_get_path (cairo_pattern_t *pattern,
        unsigned int patch_num);
 cairo_status_t
cairo_mesh_pattern_get_corner_color_rgba (cairo_pattern_t *pattern,
       unsigned int patch_num,
       unsigned int corner_num,
       double *red, double *green,
       double *blue, double *alpha);
 cairo_status_t
cairo_mesh_pattern_get_control_point (cairo_pattern_t *pattern,
          unsigned int patch_num,
          unsigned int point_num,
          double *x, double *y);
 void
cairo_matrix_init (cairo_matrix_t *matrix,
     double xx, double yx,
     double xy, double yy,
     double x0, double y0);
 void
cairo_matrix_init_identity (cairo_matrix_t *matrix);
 void
cairo_matrix_init_translate (cairo_matrix_t *matrix,
        double tx, double ty);
 void
cairo_matrix_init_scale (cairo_matrix_t *matrix,
    double sx, double sy);
 void
cairo_matrix_init_rotate (cairo_matrix_t *matrix,
     double radians);
 void
cairo_matrix_translate (cairo_matrix_t *matrix, double tx, double ty);
 void
cairo_matrix_scale (cairo_matrix_t *matrix, double sx, double sy);
 void
cairo_matrix_rotate (cairo_matrix_t *matrix, double radians);
 cairo_status_t
cairo_matrix_invert (cairo_matrix_t *matrix);
 void
cairo_matrix_multiply (cairo_matrix_t *result,
         const cairo_matrix_t *a,
         const cairo_matrix_t *b);
 void
cairo_matrix_transform_distance (const cairo_matrix_t *matrix,
     double *dx, double *dy);
 void
cairo_matrix_transform_point (const cairo_matrix_t *matrix,
         double *x, double *y);
typedef struct _cairo_region cairo_region_t;
typedef enum _cairo_region_overlap {
    CAIRO_REGION_OVERLAP_IN,
    CAIRO_REGION_OVERLAP_OUT,
    CAIRO_REGION_OVERLAP_PART
} cairo_region_overlap_t;
 cairo_region_t *
cairo_region_create (void);
 cairo_region_t *
cairo_region_create_rectangle (const cairo_rectangle_int_t *rectangle);
 cairo_region_t *
cairo_region_create_rectangles (const cairo_rectangle_int_t *rects,
    int count);
 cairo_region_t *
cairo_region_copy (const cairo_region_t *original);
 cairo_region_t *
cairo_region_reference (cairo_region_t *region);
 void
cairo_region_destroy (cairo_region_t *region);
 cairo_bool_t
cairo_region_equal (const cairo_region_t *a, const cairo_region_t *b);
 cairo_status_t
cairo_region_status (const cairo_region_t *region);
 void
cairo_region_get_extents (const cairo_region_t *region,
     cairo_rectangle_int_t *extents);
 int
cairo_region_num_rectangles (const cairo_region_t *region);
 void
cairo_region_get_rectangle (const cairo_region_t *region,
       int nth,
       cairo_rectangle_int_t *rectangle);
 cairo_bool_t
cairo_region_is_empty (const cairo_region_t *region);
 cairo_region_overlap_t
cairo_region_contains_rectangle (const cairo_region_t *region,
     const cairo_rectangle_int_t *rectangle);
 cairo_bool_t
cairo_region_contains_point (const cairo_region_t *region, int x, int y);
 void
cairo_region_translate (cairo_region_t *region, int dx, int dy);
 cairo_status_t
cairo_region_subtract (cairo_region_t *dst, const cairo_region_t *other);
 cairo_status_t
cairo_region_subtract_rectangle (cairo_region_t *dst,
     const cairo_rectangle_int_t *rectangle);
 cairo_status_t
cairo_region_intersect (cairo_region_t *dst, const cairo_region_t *other);
 cairo_status_t
cairo_region_intersect_rectangle (cairo_region_t *dst,
      const cairo_rectangle_int_t *rectangle);
 cairo_status_t
cairo_region_union (cairo_region_t *dst, const cairo_region_t *other);
 cairo_status_t
cairo_region_union_rectangle (cairo_region_t *dst,
         const cairo_rectangle_int_t *rectangle);
 cairo_status_t
cairo_region_xor (cairo_region_t *dst, const cairo_region_t *other);
 cairo_status_t
cairo_region_xor_rectangle (cairo_region_t *dst,
       const cairo_rectangle_int_t *rectangle);
 void
cairo_debug_reset_static_data (void);

// private APIs

typedef enum _cairo_lcd_filter {
    CAIRO_LCD_FILTER_DEFAULT,
    CAIRO_LCD_FILTER_NONE,
    CAIRO_LCD_FILTER_INTRA_PIXEL,
    CAIRO_LCD_FILTER_FIR3,
    CAIRO_LCD_FILTER_FIR5
} cairo_lcd_filter_t;

typedef enum _cairo_round_glyph_pos {
    CAIRO_ROUND_GLYPH_POS_DEFAULT,
    CAIRO_ROUND_GLYPH_POS_ON,
    CAIRO_ROUND_GLYPH_POS_OFF
} cairo_round_glyph_positions_t;

void _cairo_font_options_set_lcd_filter (cairo_font_options_t   *options, cairo_lcd_filter_t  lcd_filter);
cairo_lcd_filter_t _cairo_font_options_get_lcd_filter (const cairo_font_options_t *options);
void _cairo_font_options_set_round_glyph_positions (cairo_font_options_t *options, cairo_round_glyph_positions_t  round);
cairo_round_glyph_positions_t _cairo_font_options_get_round_glyph_positions (const cairo_font_options_t *options);

















































--probing C namespace (returns nil for missing symbols)
local function sym(name) return C[name] end
local _C = setmetatable({}, {__index = function(C, k)
    return pcall(sym, k) and C[name] or nil
end})
M._C = _C

--set up M for auto-lookup of C.cairo_<symbol> or C.CAIRO_<SYMBOL> or C.<symbol>
setmetatable(M, {__index = function(t, k, v)
	local sym = _C[(k:upper() == k and 'CAIRO_' or 'cairo_')..k] or C[k]
	rawset(t, k, sym)
	return sym
end})


-- garbage collector / ref'counting integration
-- NOTE: free() and destroy() do not return a value to enable the idiom
-- self.obj = self.obj:free().

--generic free() method for reference-counted objects: crash if there are still references.
local function free_ref_counted(self)
	local n = self:get_reference_count() - 1
	self:destroy()
	if n ~= 0  then
		error(string.format('refcount of %s is %d, should be 0', tostring(self), n))
	end
end

local function destroy_func(destroy)
	return function(self)
		ffi.gc(self, nil)
		destroy(self)
	end
end

local function ref_func(reference, destroy)
	return function(...)
		return ffi.gc(reference(...), destroy)
	end
end

local function create_func(create, destroy)
	return function(...)
		return ffi.gc(create(...), destroy)
	end
end

local function setflag_func(set, prefix)
	return set and function(self, flag)
		set(self, X(prefix, flag))
	end
end

local function getflag_func(get, prefix)
	return get and function(self)
		return Y(prefix, get(self))
	end
end

local function getset_func(get, set)
	return (get or set) and function(self, val)
		if val == nil then --get val
			return get(self, val)
		else --set val
			set(self, val)
		end
	end
end

local function getsetflag_func(get, set, prefix)
	local get = getflag_func(get, prefix)
	local set = setflag_func(set, prefix)
	return getset_func(get, set)
end

-- char* return -> string return

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

--contexts -------------------------------------------------------------------

M.destroy = destroy_func(C.cairo_destroy)
M.create  = create_func(C.cairo_create, M.destroy)
M.reference = ref_func(C.cairo_reference, M.destroy)

M.scaled_font_destroy = destroy_func(C.cairo_scaled_font_destroy)
M.font_face_destroy = destroy_func(C.cairo_font_face_destroy)
M.path_destroy = destroy_func(C.cairo_path_destroy)
M.rectangle_list_destroy = destroy_func(C.cairo_rectangle_list_destroy)
M.glyph_free = destroy_func(C.cairo_glyph_free)
M.text_cluster_free = destroy_func(C.cairo_text_cluster_free)
M.pattern_destroy = destroy_func(C.cairo_pattern_destroy)

M.pop_group = ref_func(M.pop_group, M.pattern_destroy)

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

--surfaces -------------------------------------------------------------------

local function check_surface(surface)
	assert(surface:status() == C.CAIRO_STATUS_SUCCESS, surface:status_string())
	return surface
end

local function surface_func(func)
	return check_surface(func(...))
end

M.surface_destroy = destroy_func(C.cairo_surface_destroy)
M.surface_reference = ref_func(C.cairo_surface_reference, M.surface_destroy)

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

local cairo_formats = {
	bgra8  = C.CAIRO_FORMAT_ARGB32,
	bgrx8  = C.CAIRO_FORMAT_RGB24,
	g8     = C.CAIRO_FORMAT_A8,
	g1     = C.CAIRO_FORMAT_A1,
	rgb565 = C.CAIRO_FORMAT_RGB16_565,
}
M.image_surface_create = create_func(surface_func(function(fmt, w, h)
	if type(fmt) == 'table' then
		local bmp = fmt
		local format = assert(cairo_formats[bmp.format], 'unsupported format')
		return C.cairo_image_surface_create_for_data(bmp.data, format, bmp.w, bmp.h, bmp.stride)
	else
		return C.cairo_image_surface_create(fmt, w, h)
	end
end), M.surface_destroy)

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

function M.surface_map_to_image(sr, x, y, w, h)
	local image = check_surface(C.cairo_surface_map_to_image(sr, set_int_rect(x, y, w, h)))
	return ffi.gc(image, function()
		C.cairo_surface_unmap_image(sr, image)
	end)
end

function M.surface_unmap_image(sr, image)
	ffi.gc(image, nil)
	C.cairo_surface_unmap_image(sr, image)
end

--surface additions

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

--patterns -------------------------------------------------------------------

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

--scaled fonts ---------------------------------------------------------------

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

--font options ---------------------------------------------------------------

function M.font_options_create()
	return ffi.gc(C.cairo_font_options_create(), M.font_options_destroy)
end

M.font_options_destroy = destroy_func(C.cairo_font_options_destroy)

-- create/return created font options object
local function get_font_options_function(cfunc)
	return function(sr, fopt)
		fopt = fopt or M.font_options_create()
		cfunc(sr, fopt)
		return fopt
	end
end
M.get_font_options             = get_font_options_function(C.cairo_get_font_options)
M.surface_get_font_options     = get_font_options_function(C.cairo_surface_get_font_options)
M.scaled_font_get_font_options = get_font_options_function(C.scaled_font_get_font_options)

M.font_options_antialias             = getsetflag_func(C.cairo_font_options_get_antialias,              C.cairo_font_options_set_antialias, 'CAIRO_ANTIALIAS_')
M.font_options_subpixel_order        = getsetflag_func(C.cairo_font_options_get_subpixel_order,         C.cairo_font_options_set_subpixel_order, 'CAIRO_SUBPIXEL_ORDER_')
M.font_options_hint_style            = getsetflag_func(C.cairo_font_options_get_hint_style,             C.cairo_font_options_set_hint_style, 'CAIRO_HINT_STYLE_')
M.font_options_hint_metrics          = getsetflag_func(C.cairo_font_options_get_hint_metrics,           C.cairo_font_options_set_hint_metrics, 'CAIRO_HINT_METRICS_')
M.font_options_lcd_filter            = getsetflag_func(_C.cairo_font_options_get_lcd_filter,            _C.cairo_font_options_set_lcd_filter, 'CAIRO_LCD_FILTER_')
M.font_options_round_glyph_positions = getsetflag_func(_C.cairo_font_options_get_round_glyph_positions, _C.cairo_font_options_set_round_glyph_positions, 'CAIRO_ROUND_GLYPH_POS_')

M.font_options_equal = returns_bool(M.font_options_equal)

ffi.metatype('cairo_font_options_t', {__index = {
	copy = M.font_options_copy,
	free = M.font_options_destroy,
	status = M.font_options_status,
	status_string = status_string,
	merge = M.font_options_merge,
	equal = M.font_options_equal,
	hash = M.font_options_hash,
	antialias = M.font_options_antialias,
	subpixel_order = M.font_options_subpixel_order,
	hint_style = M.font_options_hint_style,
	hint_metrics = M.font_options_hint_metrics,
	lcd_filter = M.font_options_lcd_filter,
	round_glyph_positions = M.font_options_round_glyph_positions,
}, __eq = M.font_options_equal,
})

--regions --------------------------------------------------------------------

function M.region_create(...)
	return ffi.gc(C.cairo_region_create(...), M.region_destroy)
end

M.region_destroy = destroy_func(C.cairo_region_destroy)

local r = ffi.new'cairo_rectangle_int_t'
local function set_int_rect(x, y, w, h)
	if not x then return end
	r.x = x
	r.y = y
	r.width = w
	r.height = h
end

local function unpack_int_rect(r)
	return r.x, r.y, r.width, r.height
end

function M.region_create_rectangle(x, y, w, h)
	return ffi.gc(C.cairo_region_create_rectangle(set_int_rect(x, y, w, h)), M.region_destroy)
end

function M.region_create_rectangles(rects)
	return ffi.gc(C.cairo_region_create_rectangles(rects), M.region_destroy)
end

function M.region_copy(rgn)
	return ffi.gc(C.cairo_region_copy(rgn), M.region_destroy)
end

function M.region_get_extents(rgn)
	C.cairo_region_get_extents(rgn, r)
	return unpack_int_rect(r)
end

function M.region_get_rectangle(rgn, n)
	C.cairo_region_get_rectangle(rgn, n, r)
	return unpack_int_rect(r)
end

local function op_func(rgn_func_name)
	local rgn_func = C['cairo_'..rgn_func_name]
	local rect_func = C['cairo_'..rgn_func_name..'_rectangle']
	return function(rgn, x, y, w, h)
		if type(x) == 'cdata' then
			return rgn_func(rgn, x)
		end
		return rect_func(rgn, set_int_rect(x, y, w, h))
	end
end

local function overlap = {
	[C.CAIRO_REGION_OVERLAP_IN] = true,
	[C.CAIRO_REGION_OVERLAP_OUT = false,
	[C.CAIRO_REGION_OVERLAP_PART] = 'partial',
}
local region_contains = op_func'region_contains'
function M.region_contains(...)
	return overlap[region_contains(...)]
end

M.region_subtract  = op_func'region_subtract'
M.region_intersect = op_func'region_intersect'
M.region_union     = op_func'region_union'
M.region_xor       = op_func'region_xor'

function M.region_reference(...)
	return ffi.gc(C.cairo_region_reference(...), M.region_destroy)
end

ffi.metatype('cairo_region_t', {__index = {
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
	intersect = M.region_intersect,
	union = M.region_union,
	xor = M.region_xor,
}, __eq = M.region_equal})

--paths ----------------------------------------------------------------------

function M.copy_path(...)
	return ffi.gc(C.cairo_copy_path(...), M.path_destroy)
end

function M.copy_path_flat(...)
	return ffi.gc(C.cairo_copy_path_flat(...), M.path_destroy)
end

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

--............................................................................

function M.copy_clip_rectangle_list(...)
	return ffi.gc(C.cairo_copy_clip_rectangle_list(...), M.rectangle_list_destroy)
end

function M.glyph_allocate(...)
	return ffi.gc(C.cairo_glyph_allocate(...), M.glyph_free)
end

function M.text_cluster_allocate(...)
	return ffi.gc(C.cairo_text_cluster_allocate(...), M.text_cluster_free)
end

M.in_stroke = returns_bool(M.in_stroke)
M.in_fill = returns_bool(M.in_fill)
M.in_clip = returns_bool(M.in_clip)
M.has_current_point = returns_bool(M.has_current_point)
M.surface_has_show_text_glyphs = returns_bool(M.surface_has_show_text_glyphs)
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

--matrices -------------------------------------------------------------------

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

-- luaization overrides

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

function M.cairo_select_font_face(cr, family, slant, weight)
	C.cairo_select_font_face(cr, family,
		X('CAIRO_FONT_SLANT_', slant),
		X('CAIRO_FONT_WEIGHT_', weight))
end

--devices --------------------------------------------------------------------

M.device_destroy   = destroy_func(C.cairo_device_destroy)
M.device_reference = ref_func(C.cairo_device_reference, M.device_destroy)

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

-- metamethods

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

return M
