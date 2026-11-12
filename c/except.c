#include "tinkwan_asm.h"
#include "tinkwan_except.h"
#include "tinkwan_hash.h"
#include "tinkwan_mem.h"
#include "tinkwan_multic.h"
#include "tinkwan_que.h"
#include <setjmp.h>
#include <string.h>
// See TINKWANIOS_enter_try t in except_*.s
jmp_buf *__enter_try() {
  CExcept *ex = A_MALLOC(sizeof(CExcept), Fs);
  QueIns(ex, Fs->except->last);
  Fs->catch_except = 0;
  return &ex->ctx;
}
jmp_buf *__throw(uint64_t code) {
  Fs->except_ch = code;
  CExcept *ex;
  Fs->catch_except = 0;
  Fs->except_ch = code;
  QueRem(ex = Fs->except->last);
  memcpy(Fs->throw_pad, ex->ctx, sizeof(ex->ctx));
  A_FREE(ex);
  return &(Fs->throw_pad);
}
void TINKWANIOS_ExitCatch() {
  if (Fs->catch_except) {
    Fs->catch_except = 0;
  } else
    throw(Fs->except_ch);
}

int64_t TINKWANIOS_enter_try() {
  return !setjmp(*__enter_try());
}

void TINKWANIOS_throw(uint64_t c) {
  static CHashExport *exp;
  if (!exp)
    exp = HashFind("throw", Fs->hash_table, HTT_EXPORT_SYS_SYM, 1);
  FFI_CALL_TOS_1(exp->val, c);
  __builtin_unreachable();
}
