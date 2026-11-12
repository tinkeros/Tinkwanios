#pragma once
#include <stdint.h>
void SndFreq(int64_t f);
void InitSound();
void TinkwaniosSetVolume(double v);
double TinkwaniosGetVolume();
void DeinitSound();
// The PCM ring the HolyC sound stack fills. See c/sound.c.
int64_t SndHostInit(int64_t rate, int64_t channels, int64_t buf_len);
int64_t SndHostFree();
int64_t SndHostBufNum();
void SndHostPush(int32_t *buf);
int64_t SndHostCapInit(int64_t rate, int64_t channels, int64_t buf_len);
void SndHostCapRun(int64_t on);
int64_t SndHostCapPull(int16_t *buf);
