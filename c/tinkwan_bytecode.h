#pragma once
#ifdef USE_BYTECODE
#include <stdint.h>
#include "tinkwan_lexparser.h"
#include "tinkwan_mem.h"
#define IM_STK_SIZE 32
typedef struct ABCFrame {
  union {
    double fstk[IM_STK_SIZE];
    int64_t istk[IM_STK_SIZE];
    uint64_t ustk[IM_STK_SIZE];
  };
  struct ABCFrame *next;
  int64_t sp;
} ABCFrame;
typedef struct ABCState {
  ABCFrame *fun_frame;
  int64_t ip, fp, frame_sz,_sp;
} ABCState;
char *OptPassFinalBC(CCmpCtrl *cctrl, int64_t *res_sz, char **dbg_info,
                   CHeapCtrl *heap);
int64_t TinkwanRunBC(ABCState *state);
ABCState *ABCStateNew(void *bc_addr,void *stk_fptr,int64_t argc,int64_t *argv);
void ABCStateDel(ABCState *st);
int64_t ABCRun_Done(ABCState *st,int64_t *retval);
void TinkwanBCDel(char *bc);
int64_t ABCRun(ABCState *st);
uint32_t *BCGenerateFFICall(void *fcall);
uint64_t TinkwanBCContextSet(ABCState **to_stk);
uint64_t TinkwanBCContextGet(ABCState **to_stk);
int64_t TinkwanBCCallArgs(void *bc,int64_t argc,int64_t *argv);
int64_t TinkwanBCCall(void *bc);
int64_t TinkwanBC_FP(int64_t*);
int64_t TinkwanBCMakeContext(int64_t *to_stk);
int64_t TinkwanBCTaskContextSetRIP(int64_t *stk);
int64_t TinkwanBCTaskContextGetRIP(int64_t *stk);
int64_t TinkwanBCTaskContextGetRBP(int64_t *stk);
void *TinkwanBCDbgCurContext();
void TinkwanBCDbgFault(int sigh);
int64_t BCAwake() ;
void BCInterupt() ;
char *CompileBC(CCmpCtrl *cctrl, int64_t *res_sz, char **dbg_info,
                       CHeapCtrl *heap);
#endif
