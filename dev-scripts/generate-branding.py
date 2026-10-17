#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""Render iLiberated's original vector and PNG artwork using Cairo/FreeType."""

import ctypes as ct
from ctypes.util import find_library
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BACKGROUND = (16 / 255, 31 / 255, 47 / 255)
ACCENT = (104 / 255, 224 / 255, 178 / 255)
WHITE = (240 / 255, 248 / 255, 250 / 255)


def library(name):
    path = find_library(name)
    if path is None:
        raise SystemExit(f"Install the {name} shared library to render the artwork.")
    return ct.CDLL(path)


def bind(lib, name, result, *arguments):
    function = getattr(lib, name)
    function.restype = result
    function.argtypes = arguments
    return function


cairo = library("cairo")
freetype = library("freetype")
ptr, num, integer, string = ct.c_void_p, ct.c_double, ct.c_int, ct.c_char_p
image_surface = bind(cairo, "cairo_image_surface_create", ptr, integer, integer, integer)
svg_surface = bind(cairo, "cairo_svg_surface_create", ptr, string, num, num)
create = bind(cairo, "cairo_create", ptr, ptr)
destroy = bind(cairo, "cairo_destroy", None, ptr)
finish = bind(cairo, "cairo_surface_finish", None, ptr)
surface_destroy = bind(cairo, "cairo_surface_destroy", None, ptr)
surface_status = bind(cairo, "cairo_surface_status", integer, ptr)
status = bind(cairo, "cairo_status", integer, ptr)
write_png = bind(cairo, "cairo_surface_write_to_png", integer, ptr, string)
color = bind(cairo, "cairo_set_source_rgb", None, ptr, num, num, num)
rectangle = bind(cairo, "cairo_rectangle", None, ptr, num, num, num, num)
fill = bind(cairo, "cairo_fill", None, ptr)
move_to = bind(cairo, "cairo_move_to", None, ptr, num, num)
line_to = bind(cairo, "cairo_line_to", None, ptr, num, num)
line_width = bind(cairo, "cairo_set_line_width", None, ptr, num)
stroke = bind(cairo, "cairo_stroke", None, ptr)
scale = bind(cairo, "cairo_scale", None, ptr, num, num)
translate = bind(cairo, "cairo_translate", None, ptr, num, num)
save = bind(cairo, "cairo_save", None, ptr)
restore = bind(cairo, "cairo_restore", None, ptr)
set_font = bind(cairo, "cairo_set_font_face", None, ptr, ptr)
font_size = bind(cairo, "cairo_set_font_size", None, ptr, num)
text_path = bind(cairo, "cairo_text_path", None, ptr, string)


def check(code):
    if code != 0:
        raise RuntimeError(f"Artwork rendering failed (status {code}).")


ft = ptr()
check(bind(freetype, "FT_Init_FreeType", integer, ct.POINTER(ptr))(ct.byref(ft)))
face = ptr()
check(bind(freetype, "FT_New_Face", integer, ptr, string, ct.c_long, ct.POINTER(ptr))(
    ft, bytes(ROOT / "touchHLE_fonts/LiberationSans-Bold.ttf"), 0, ct.byref(face)
))
font = bind(cairo, "cairo_ft_font_face_create_for_ft_face", ptr, ptr, integer)(face, 0)


def box(context, x, y, width, height, ink):
    color(context, *ink)
    rectangle(context, x, y, width, height)
    fill(context)


def icon(context):
    """An open frame, an iL monogram and pixels escaping the top corner."""
    box(context, 0, 0, 1024, 1024, BACKGROUND)
    color(context, *ACCENT)
    line_width(context, 48)
    move_to(context, 504, 240)
    for x, y in [(248, 240), (248, 792), (776, 792), (776, 536)]:
        line_to(context, x, y)
    stroke(context)
    for rect in [(352, 384, 80, 80), (352, 512, 80, 168),
                 (512, 384, 80, 296), (592, 600, 88, 80)]:
        box(context, *rect, WHITE)
    box(context, 592, 256, 88, 88, ACCENT)
    box(context, 736, 112, 112, 112, ACCENT)


def logo(context):
    box(context, 0, 0, 1200, 280, BACKGROUND)
    save(context)
    translate(context, 8, 12)
    scale(context, 0.25, 0.25)
    icon(context)
    restore(context)
    color(context, *WHITE)
    set_font(context, font)
    font_size(context, 172)
    move_to(context, 286, 197)
    # Outlines keep the SVG portable; no installed font is needed to view it.
    text_path(context, b"iLiberated")
    fill(context)


def render(path, width, height, draw, factor=1):
    path = ROOT / path
    vector = path.suffix == ".svg"
    # RGB24 produces opaque PNGs, as required for an iOS app icon.
    surface = (svg_surface(bytes(path), width, height) if vector
               else image_surface(1, width, height))
    check(surface_status(surface))
    context = create(surface)
    scale(context, factor, factor)
    draw(context)
    check(status(context))
    if not vector:
        check(write_png(surface, bytes(path)))
    destroy(context)
    finish(surface)
    check(surface_status(surface))
    surface_destroy(surface)
    print(path.relative_to(ROOT))


render("res/icon.svg", 1024, 1024, icon)
render("res/logo.svg", 1200, 280, logo)
render("res/icon.png", 512, 512, icon, 0.5)
render("iphone/iLiberated/Assets.xcassets/AppIcon.appiconset/AppIcon.png", 1024, 1024, icon)
render("iphone/iLiberated/Assets.xcassets/AppPickerLogo.imageset/AppPickerLogo@3x.png",
       1200, 280, logo)

bind(cairo, "cairo_font_face_destroy", None, ptr)(font)
check(bind(freetype, "FT_Done_Face", integer, ptr)(face))
check(bind(freetype, "FT_Done_FreeType", integer, ptr)(ft))
