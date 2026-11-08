/* Kiểm tra FFI từ C: clang ffi_smoke.c -I../include -L<lib> -lphimviet */
#include "phimviet.h"
#include <stdio.h>
#include <string.h>

static int fails = 0;
static void expect(PvResult r, int kind, const char *text) {
    const char *t = r.text ? r.text : "";
    if (r.kind != kind || strcmp(t, text) != 0) {
        printf("FAIL: kind=%d text=\"%s\" (cần %d \"%s\")\n", r.kind, t, kind, text);
        fails++;
    }
    pv_string_free(r.text);
}

int main(void) {
    PvEngine *e = pv_engine_new();
    const char *keys = "tieengs";
    for (size_t i = 0; keys[i]; i++) {
        PvResult r = pv_process(e, (uint32_t)keys[i], 0);
        if (keys[i + 1] == 0) expect(r, PV_COMPOSING, "tiếng");
        else pv_string_free(r.text);
    }
    expect(pv_backspace(e), PV_COMPOSING, "tiến");
    expect(pv_process(e, 'g', 0), PV_COMPOSING, "tiếng");
    expect(pv_commit(e, PV_BOUNDARY_SPACE, ' '), PV_COMMIT, "tiếng");
    if (pv_set_config(e, "{\"method\":\"vni\",\"macros\":{\"vn\":\"Việt Nam\"}}") != 0) { puts("FAIL config"); fails++; }
    pv_string_free(pv_process(e, 'v', 0).text);
    pv_string_free(pv_process(e, 'n', 0).text);
    expect(pv_process(e, ' ', 0), PV_COMMIT, "Việt Nam");
    expect(pv_process(e, ' ', 0), PV_UNCHANGED, "");
    if (pv_set_config(e, "not json") != -1) { puts("FAIL bad json accepted"); fails++; }
    pv_engine_free(e);
    printf("pv_version=%s, %s\n", pv_version(), fails ? "THẤT BẠI" : "OK");
    return fails ? 1 : 0;
}
