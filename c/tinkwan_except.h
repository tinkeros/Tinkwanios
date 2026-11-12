#pragma once
#include "tinkwan_que.h"
#include <setjmp.h>
#include <stdint.h>
typedef struct CExceptPad {
  int64_t gp[30 - 18 + 1];
  double fp[15 - 8 + 1];
} CExceptPad;
typedef struct CExcept {
  CQue base;
  jmp_buf ctx;
} CExcept;

#define try                                                                    \
  {                                                                            \
    if (TINKWANIOS_enter_try()) {
#define catch                                                                  \
  (body)                                                                       \
  }                                                                            \
  else {                                                                       \
    body;                                                                      \
    TINKWANIOS_ExitCatch();                                                       \
  }                                                                            \
  }
void TINKWANIOS_throw(uint64_t code);
#define throw TINKWANIOS_throw

void TINKWANIOS_ExitCatch();
jmp_buf *__throw(uint64_t code);
void TINKWANIOS_throw(uint64_t code);
int64_t TINKWANIOS_enter_try();
jmp_buf *__enter_try();
