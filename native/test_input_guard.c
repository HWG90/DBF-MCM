#include <assert.h>
#include <stdio.h>
#include "input_guard.c"
static int applied;
static int apply_pause(void) { ++applied;return 1; }
static void query_solo(MCM_PHOTO_SESSION *s) { s->session_present=1;s->other_peers=0;s->joining_peers=0; }
static void query_multi(MCM_PHOTO_SESSION *s) { query_solo(s);s->other_peers=1; }
static void query_unknown(MCM_PHOTO_SESSION *s) { (void)s; }
int main(void) {
    assert(mcm_policy(WM_KEYDOWN,0,1));assert(mcm_policy(WM_KEYUP,0,1));
    assert(mcm_policy(WM_CHAR,0,1));assert(mcm_policy(WM_SYSKEYDOWN,0,1));
    assert(mcm_policy(WM_MOUSEMOVE,0,1));assert(mcm_policy(WM_LBUTTONDOWN,0,1));
    assert(mcm_policy(WM_MOUSEWHEEL,0,1));
    assert(mcm_policy(WM_INPUT,RIM_TYPEKEYBOARD,1));assert(mcm_policy(WM_INPUT,RIM_TYPEMOUSE,1));
    assert(!mcm_policy(WM_INPUT,RIM_TYPEHID,1));assert(!mcm_policy(WM_PAINT,0,1));
    assert(!mcm_policy(WM_CLOSE,0,1));assert(!mcm_policy(WM_KILLFOCUS,0,1));
    assert(!mcm_policy(WM_INPUT_DEVICE_CHANGE,0,1));
    for (UINT i=0;i<0x400;i++)assert(!mcm_policy(i,RIM_TYPEKEYBOARD,0));
    assert(keyboard_gate('A',0,1));assert(keyboard_gate('A',0,0));
    assert(keyboard_gate('A',1,0));assert(!keyboard_gate('A',0,0));
    assert(keyboard_gate('B',0,1));assert(keyboard_gate('B',1,1));assert(!keyboard_gate('B',0,0));
    assert(mouse_gate(RI_MOUSE_LEFT_BUTTON_DOWN,1));assert(mouse_gate(0,0));
    assert(mouse_gate(RI_MOUSE_LEFT_BUTTON_UP,0));assert(!mouse_gate(0,0));
    assert(mouse_flags(WM_RBUTTONUP,0)==RI_MOUSE_RIGHT_BUTTON_UP);
    assert(mouse_flags(WM_MOUSEMOVE,0)==0);
    assert(!mcm_policy(WM_MOUSEMOVE,0,2));assert(mcm_policy(WM_MOUSEWHEEL,0,2));
    assert(mcm_policy(WM_KEYDOWN,0,2));assert(!mouse_gate(0,2));
    assert(mouse_gate(RI_MOUSE_LEFT_BUTTON_DOWN,2));assert(!mouse_gate(0,2));
    assert(mouse_gate(RI_MOUSE_LEFT_BUTTON_UP,0));assert(!mouse_gate(0,0));
    assert(mcm_policy(WM_MOUSEMOVE,0,3));assert(mouse_gate(0,3));
    assert(mcm_policy(WM_INPUT,RIM_TYPEMOUSE,3));assert(mcm_policy(WM_KEYDOWN,0,3));
    InterlockedExchangeAdd(&look_x,37);InterlockedExchangeAdd(&look_y,-19);
    assert(mcm_mouse_x()==37 && mcm_mouse_y()==-19);assert(mcm_mouse_x()==0);
    InterlockedExchangeAdd(&look_x,100);mcm_release();assert(mcm_mouse_x()==0);
    assert(!mcm_capture(4));assert(!mcm_install(NULL));assert(!mcm_capture(1));mcm_release();assert(!mcm_captured());
    MCM_PHOTO_SESSION session={-1,-1,-1,-1};
    assert(!mcm_photo_policy(NULL));assert(!mcm_photo_policy(&session));
    session.session_present=1;session.other_peers=0;session.joining_peers=0;
    assert(mcm_photo_policy(&session));
    session.other_peers=1;assert(!mcm_photo_policy(&session));
    session.other_peers=0;session.joining_peers=1;assert(!mcm_photo_policy(&session));
    session.joining_peers=-1;assert(!mcm_photo_policy(&session));
    session.session_present=0;assert(!mcm_photo_policy(&session));
    session.connections=0;assert(mcm_photo_policy(&session));
    session.connections=1;assert(!mcm_photo_policy(&session));
    assert(!mcm_photo_pause(NULL,apply_pause));assert(!mcm_photo_pause(query_unknown,apply_pause));
    assert(!mcm_photo_pause(query_multi,apply_pause));assert(applied==0);
    assert(mcm_photo_pause(query_solo,apply_pause));assert(applied==1);
    assert(!mcm_photo_pause(query_solo,NULL));
    InterlockedExchange(&previous_mouse_raw,RI_MOUSE_RIGHT_BUTTON_UP);
    assert(!previous_mouse_release(&previous_mouse_raw,0));
    assert(previous_mouse_release(&previous_mouse_raw,RI_MOUSE_RIGHT_BUTTON_UP));
    assert(!previous_mouse_release(&previous_mouse_raw,RI_MOUSE_RIGHT_BUTTON_UP));
    puts("Native input policy and held-key/button release tests passed; no game window attached.");
    return 0;
}
