--result of `cpp cairo-quartz.h` from cairo 1.12.16
local ffi = require'ffi'
require'cairo_h'

local objc = require'objc'
local bs = require("objc.BridgeSupport")
bs.loadFramework("Foundation")
bs.loadFramework("AppKit")
bs.loadFramework("ApplicationServices")
bs.loadFramework("CoreGraphics")

ffi.cdef[[
typedef uint32_t ATSUFontID;

cairo_surface_t *
cairo_quartz_surface_create (cairo_format_t format,
                             unsigned int width,
                             unsigned int height);
cairo_surface_t *
cairo_quartz_surface_create_for_cg_context (CGContextRef cgContext,
                                            unsigned int width,
                                            unsigned int height);
CGContextRef
cairo_quartz_surface_get_cg_context (cairo_surface_t *surface);

// quartz font support
cairo_font_face_t *
cairo_quartz_font_face_create_for_cgfont (CGFontRef font);
cairo_font_face_t *
cairo_quartz_font_face_create_for_atsu_font_id (ATSUFontID font_id);
]]
