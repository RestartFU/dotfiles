module main

import os

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#include <X11/cursorfont.h>
#include <X11/Xft/Xft.h>
#include <X11/Xatom.h>
#flag -lX11 -lXft -lfontconfig -I/usr/include/freetype2

@[typedef]
struct C.Display {

}

@[typedef]
struct C.Window {}

fn C.XOpenDisplay(&u8) &C.Display

fn C.XCloseDisplay(&C.Display)

fn C.XDefaultRootWindow(&C.Display) C.Window



/*

int (*XSetErrorHandler(handler))()
      int (*handler)(Display *, XErrorEvent *)

void
checkotherwm(void)
{
	xerrorxlib = XSetErrorHandler(xerrorstart);
	/* this causes an error if some other window manager is running */
	XSelectInput(dpy, DefaultRootWindow(dpy), SubstructureRedirectMask);
	XSync(dpy, False);
	XSetErrorHandler(xerror);
	XSync(dpy, False);
}

int
xerrorstart(Display *dpy, XErrorEvent *ee)
{
	die("dwm: another window manager is already running");
	return -1;
}

*/


fn checkotherwm() {
	xerrorxlib := x
}

fn main() {
	dpy := C.XOpenDisplay(unsafe{nil})
	if unsafe{dpy == nil}{
		panic("dwm: cannot open display")
	}
	root := C.XDefaultRootWindow(dpy)
	C.XCloseDisplay(dpy)
}