#pragma once
#include <stdint.h>
int64_t IsCmdLineMode2();
void TermSetKbCb(void *fptr, void *);
void TinkwaniosTUIEnable();
void TermSize(int64_t *a, int64_t *b);
void TermSetMsCb(void *);
void TUIInputLoop();
