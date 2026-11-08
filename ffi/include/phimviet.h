/*
 * phimviet.h — C ABI của lõi bộ gõ Phím Việt (viết tay, khớp ffi/src/lib.rs).
 *
 * Bộ nhớ: mọi `char *` trả về là UTF-8 do Rust cấp phát; giải phóng ĐÚNG MỘT LẦN bằng
 * pv_string_free(). Engine không an toàn đa luồng: mỗi engine chỉ dùng trên một luồng.
 * Không panic nào đi xuyên ABI: lỗi bên trong → engine reset, kết quả PV_UNCHANGED.
 *
 * SPDX-License-Identifier: MIT
 */
#ifndef PHIMVIET_H
#define PHIMVIET_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct PvEngine PvEngine;

/* PvResult.kind */
#define PV_UNCHANGED 0 /* engine không xử lý: đưa phím cho ứng dụng */
#define PV_COMPOSING 1 /* text = chữ hiển thị mới của từ (có thể rỗng) */
#define PV_COMMIT 2    /* text = chữ chốt; pass_through → đưa phím cho ứng dụng */

/* cờ cho pv_process */
#define PV_FLAG_SHIFT 1u
#define PV_FLAG_CAPS 2u

/* ranh giới cho pv_commit */
#define PV_BOUNDARY_SPACE 0
#define PV_BOUNDARY_ENTER 1
#define PV_BOUNDARY_TAB 2
#define PV_BOUNDARY_CHAR 3
#define PV_BOUNDARY_MOUSE 4
#define PV_BOUNDARY_FOCUS 5
#define PV_BOUNDARY_OTHER 6

typedef struct PvResult {
    int32_t kind;
    char *text; /* NULL khi PV_UNCHANGED; nếu khác NULL phải pv_string_free */
    bool pass_through;
} PvResult;

PvEngine *pv_engine_new(void);
void pv_engine_free(PvEngine *engine);

/* JSON: {"method":"telex|vni|simple_telex","tone_style":"new|old","spell_check":true,
 *        "auto_restore":true,"w_as_u":true,"brackets":false,"macros_enabled":true,
 *        "macros":{"vn":"Việt Nam"}}  — trả 0 nếu thành công, -1 nếu lỗi. */
int32_t pv_set_config(PvEngine *engine, const char *json);

PvResult pv_process(PvEngine *engine, uint32_t codepoint, uint32_t flags);
PvResult pv_backspace(PvEngine *engine);
PvResult pv_commit(PvEngine *engine, int32_t boundary, uint32_t codepoint);
PvResult pv_restore_raw(PvEngine *engine);
/* Nạp lại một từ có sẵn trong văn bản để sửa dấu tiếp ("may" → "mấy"). true nếu thành công. */
bool pv_load_word(PvEngine *engine, const char *word);
void pv_reset(PvEngine *engine);
bool pv_is_composing(const PvEngine *engine);
char *pv_composing(const PvEngine *engine);

void pv_string_free(char *s);
const char *pv_version(void); /* chuỗi tĩnh — KHÔNG giải phóng */

#ifdef __cplusplus
}
#endif

#endif /* PHIMVIET_H */
