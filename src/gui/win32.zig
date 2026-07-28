//! Minimal Win32 bindings needed to host a child window with an OpenGL context.
//! Only the handful of types, constants and functions the GUI uses are declared.

const std = @import("std");

pub const WINAPI: std.builtin.CallingConvention = .winapi;

pub const HWND = ?*anyopaque;
pub const HDC = ?*anyopaque;
pub const HGLRC = ?*anyopaque;
pub const HINSTANCE = ?*anyopaque;
pub const HMODULE = ?*anyopaque;
pub const HICON = ?*anyopaque;
pub const HCURSOR = ?*anyopaque;
pub const HBRUSH = ?*anyopaque;
pub const HMENU = ?*anyopaque;

pub const WPARAM = usize;
pub const LPARAM = isize;
pub const LRESULT = isize;
pub const UINT = c_uint;
pub const DWORD = c_ulong;
pub const WORD = c_ushort;
pub const BYTE = u8;
pub const ATOM = c_ushort;
pub const BOOL = c_int;
pub const LONG = c_long;
pub const UINT_PTR = usize;

pub const WNDPROC = *const fn (HWND, UINT, WPARAM, LPARAM) callconv(WINAPI) LRESULT;

pub const RECT = extern struct { left: LONG, top: LONG, right: LONG, bottom: LONG };
pub const POINT = extern struct { x: LONG, y: LONG };

pub const WNDCLASSEXW = extern struct {
    cbSize: UINT,
    style: UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: c_int,
    cbWndExtra: c_int,
    hInstance: HINSTANCE,
    hIcon: HICON,
    hCursor: HCURSOR,
    hbrBackground: HBRUSH,
    lpszMenuName: ?[*:0]const u16,
    lpszClassName: ?[*:0]const u16,
    hIconSm: HICON,
};

pub const PIXELFORMATDESCRIPTOR = extern struct {
    nSize: WORD,
    nVersion: WORD,
    dwFlags: DWORD,
    iPixelType: BYTE,
    cColorBits: BYTE,
    cRedBits: BYTE,
    cRedShift: BYTE,
    cGreenBits: BYTE,
    cGreenShift: BYTE,
    cBlueBits: BYTE,
    cBlueShift: BYTE,
    cAlphaBits: BYTE,
    cAlphaShift: BYTE,
    cAccumBits: BYTE,
    cAccumRedBits: BYTE,
    cAccumGreenBits: BYTE,
    cAccumBlueBits: BYTE,
    cAccumAlphaBits: BYTE,
    cDepthBits: BYTE,
    cStencilBits: BYTE,
    cAuxBuffers: BYTE,
    iLayerType: BYTE,
    bReserved: BYTE,
    dwLayerMask: DWORD,
    dwVisibleMask: DWORD,
    dwDamageMask: DWORD,
};

// Window class / style constants.
pub const CS_VREDRAW: UINT = 0x0001;
pub const CS_HREDRAW: UINT = 0x0002;
pub const CS_OWNDC: UINT = 0x0020;

pub const WS_CHILD: DWORD = 0x40000000;
pub const WS_VISIBLE: DWORD = 0x10000000;
pub const WS_CLIPSIBLINGS: DWORD = 0x04000000;
pub const WS_CLIPCHILDREN: DWORD = 0x02000000;

pub const SW_SHOW: c_int = 5;
pub const SW_HIDE: c_int = 0;

pub const SWP_NOZORDER: UINT = 0x0004;
pub const SWP_NOACTIVATE: UINT = 0x0010;

// Window messages.
pub const WM_DESTROY: UINT = 0x0002;
pub const WM_SIZE: UINT = 0x0005;
pub const WM_TIMER: UINT = 0x0113;
pub const WM_MOUSEMOVE: UINT = 0x0200;
pub const WM_LBUTTONDOWN: UINT = 0x0201;
pub const WM_LBUTTONUP: UINT = 0x0202;

pub const GWLP_USERDATA: c_int = -21;

// Pixel format flags.
pub const PFD_DRAW_TO_WINDOW: DWORD = 0x00000004;
pub const PFD_SUPPORT_OPENGL: DWORD = 0x00000020;
pub const PFD_DOUBLEBUFFER: DWORD = 0x00000001;
pub const PFD_TYPE_RGBA: BYTE = 0;
pub const PFD_MAIN_PLANE: BYTE = 0;

pub extern "user32" fn RegisterClassExW(*const WNDCLASSEXW) callconv(WINAPI) ATOM;
pub extern "user32" fn UnregisterClassW(?[*:0]const u16, HINSTANCE) callconv(WINAPI) BOOL;
pub extern "user32" fn CreateWindowExW(
    dwExStyle: DWORD,
    lpClassName: ?[*:0]const u16,
    lpWindowName: ?[*:0]const u16,
    dwStyle: DWORD,
    x: c_int,
    y: c_int,
    nWidth: c_int,
    nHeight: c_int,
    hWndParent: HWND,
    hMenu: HMENU,
    hInstance: HINSTANCE,
    lpParam: ?*anyopaque,
) callconv(WINAPI) HWND;
pub extern "user32" fn DestroyWindow(HWND) callconv(WINAPI) BOOL;
pub extern "user32" fn DefWindowProcW(HWND, UINT, WPARAM, LPARAM) callconv(WINAPI) LRESULT;
pub extern "user32" fn ShowWindow(HWND, c_int) callconv(WINAPI) BOOL;
pub extern "user32" fn SetTimer(HWND, UINT_PTR, UINT, ?*anyopaque) callconv(WINAPI) UINT_PTR;
pub extern "user32" fn KillTimer(HWND, UINT_PTR) callconv(WINAPI) BOOL;
pub extern "user32" fn GetClientRect(HWND, *RECT) callconv(WINAPI) BOOL;
pub extern "user32" fn SetWindowLongPtrW(HWND, c_int, isize) callconv(WINAPI) isize;
pub extern "user32" fn GetWindowLongPtrW(HWND, c_int) callconv(WINAPI) isize;
pub extern "user32" fn SetWindowPos(HWND, HWND, c_int, c_int, c_int, c_int, UINT) callconv(WINAPI) BOOL;
pub extern "user32" fn GetDC(HWND) callconv(WINAPI) HDC;
pub extern "user32" fn ReleaseDC(HWND, HDC) callconv(WINAPI) c_int;
pub extern "user32" fn SetCapture(HWND) callconv(WINAPI) HWND;
pub extern "user32" fn ReleaseCapture() callconv(WINAPI) BOOL;
pub extern "kernel32" fn GetModuleHandleW(?[*:0]const u16) callconv(WINAPI) HMODULE;

pub extern "gdi32" fn ChoosePixelFormat(HDC, *const PIXELFORMATDESCRIPTOR) callconv(WINAPI) c_int;
pub extern "gdi32" fn SetPixelFormat(HDC, c_int, *const PIXELFORMATDESCRIPTOR) callconv(WINAPI) BOOL;
pub extern "gdi32" fn SwapBuffers(HDC) callconv(WINAPI) BOOL;

pub extern "opengl32" fn wglCreateContext(HDC) callconv(WINAPI) HGLRC;
pub extern "opengl32" fn wglMakeCurrent(HDC, HGLRC) callconv(WINAPI) BOOL;
pub extern "opengl32" fn wglDeleteContext(HGLRC) callconv(WINAPI) BOOL;
