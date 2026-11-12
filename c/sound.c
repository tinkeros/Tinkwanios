// Two things live here. The first is the plain tone oscillator Tinkwanios has
#if !defined(__EMSCRIPTEN__)
#  include <SDL.h>
#else
#  include <SDL2/SDL.h>
#  include <emscripten.h>
#endif

#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static SDL_AudioDeviceID output;
static int64_t sample, freq;
static SDL_AudioSpec have;
static double vol = .2;

#define SND_HOST_RATE 48000
#define SND_RING_BUFS 8

static int32_t *ring[SND_RING_BUFS];
static int64_t ring_samples;             // int32 samples per buffer
static volatile int64_t ring_w, ring_r;  // written / consumed buffer counts
static int64_t ring_pos;                 // read cursor inside ring[ring_r]
static int host_mode;                    // HolyC owns the output
static int host_chans = 2;

#define SND_CAP_BUFS 8
static SDL_AudioDeviceID capture;
static SDL_AudioSpec cap_have;
static int16_t *cap_ring[SND_CAP_BUFS];
static int64_t cap_samples;             // int16 samples per buffer
static volatile int64_t cap_w, cap_r;   // written / consumed buffer counts
static int64_t cap_pos;                 // write cursor inside cap_ring[cap_w]
static int cap_mode, cap_chans = 2;

void TinkwaniosSetVolume(double v) {
  if (v > 100.)
    v = 100;
  vol = v / 100;
}
double TinkwaniosGetVolume() {
  return vol * 100;
}

static int8_t *WriteSample(int8_t *out, double v) {
  int64_t big;
  size_t bitsz = (size_t)SDL_AUDIO_BITSIZE(have.format) >> 3;
  union {
    int32_t i;
    float f;
  } f32u;
  union {
    int64_t i;
    double f;
  } f64u;
  v *= vol;
  if (v > 1.0)
    v = 1.0;
  if (v < -1.0)
    v = -1.0;
  if (SDL_AUDIO_ISFLOAT(have.format)) {
    if (SDL_AUDIO_BITSIZE(have.format) == 32) {
      f32u.f = v;
      big = f32u.i;
    } else {
      f64u.f = v;
      big = f64u.i;
    }
  } else if (SDL_AUDIO_ISSIGNED(have.format)) {
    int64_t peak = (1ull << (SDL_AUDIO_BITSIZE(have.format) - 1)) - 1;
    big = (int64_t)(v * peak);
  } else {
    int64_t peak = (1ull << (SDL_AUDIO_BITSIZE(have.format) - 1)) - 1;
    big = (int64_t)(v * peak) + peak + 1;
  }
  if (SDL_AUDIO_ISBIGENDIAN(have.format))
    switch (bitsz) {
    case 2: {
      uint16_t b = __builtin_bswap16(big);
      __builtin_memcpy(&big, &b, 2);
    } break;
    case 4: {
      uint32_t b = __builtin_bswap32(big);
      __builtin_memcpy(&big, &b, 4);
    } break;
    case 8: {
      uint64_t b = __builtin_bswap64(big);
      __builtin_memcpy(&big, &b, 8);
    } break;
    }
  __builtin_memcpy(out, &big, bitsz);
  return out + bitsz;
}

// Pull one frame out of the output ring; 0 if the producer fell behind.
static int RingFrame(double *frame) {
  int c;
  if (ring_r >= ring_w)
    return 0;
  for (c = 0; c < host_chans; c++) {
    frame[c] = ring[ring_r % SND_RING_BUFS][ring_pos + c] / 2147483648.0;
  }
  ring_pos += host_chans;
  if (ring_pos >= ring_samples) {
    ring_pos = 0;
    ring_r++;
  }
  return 1;
}

static void AudioCB(void *ul, int8_t *out, int len) {
  (void)ul;
  unsigned int i, i2;
  double frame[8];
  int64_t fpb = len / have.channels / (SDL_AUDIO_BITSIZE(have.format) / 8);
  for (i = 0; i < fpb; i++) {
    if (host_mode) {
      if (!RingFrame(frame))
        memset(frame, 0, sizeof frame);
      for (i2 = 0; i2 != have.channels; i2++)
        out = WriteSample(out, frame[i2 < (unsigned)host_chans ? i2 : 0]);
    } else {
      double t = (double)++sample / have.freq;
      double amp = freq ? sin(2.0 * M_PI * t * freq) : 0.0;
      double v = freq ? copysign(1.0, amp) : 0.0;
      for (i2 = 0; i2 != have.channels; i2++)
        out = WriteSample(out, v);
    }
  }
}

void SndFreq(int64_t f) {
  freq = f;
  if (host_mode)
    return;
  if (!f) {
    SDL_PauseAudioDevice(output, 1);
  } else
    SDL_PauseAudioDevice(output, 0);
}

// Called from HolyC to take over output with a PCM ring.
int64_t SndHostInit(int64_t rate, int64_t channels, int64_t buf_len) {
  int i;
  (void)rate; // the device is opened at SND_HOST_RATE; SDL resamples
  if (!output)
    return 0;
  if (channels < 1 || channels > 8 || buf_len < channels ||
      buf_len % channels)
    return 0;
  if (host_mode)
    return 1;
  for (i = 0; i < SND_RING_BUFS; i++) {
    if (!(ring[i] = calloc(buf_len, sizeof(int32_t))))
      return 0;
  }
  ring_samples = buf_len;
  host_chans = channels;
  ring_w = ring_r = ring_pos = 0;
  SDL_LockAudioDevice(output);
  host_mode = 1;
  SDL_UnlockAudioDevice(output);
  SDL_PauseAudioDevice(output, 0);
  return 1;
}

int64_t SndHostFree() {
  int64_t used;
  if (!host_mode)
    return 0;
  used = ring_w - ring_r;
  if (used >= SND_RING_BUFS)
    return 0;
  return SND_RING_BUFS - used;
}

int64_t SndHostBufNum() {
  return ring_r;
}

// Queue one HolyC-rendered buffer into the output ring.
void SndHostPush(int32_t *buf) {
  if (!host_mode || !buf)
    return;
  if (ring_w - ring_r >= SND_RING_BUFS)
    return; // full; drop rather than stall the producer
  memcpy(ring[ring_w % SND_RING_BUFS], buf, ring_samples * sizeof(int32_t));
  ring_w++;
}

// One capture sample, as a signed 16-bit value.
static int16_t ReadSample(int8_t **in) {
  size_t bitsz = (size_t)SDL_AUDIO_BITSIZE(cap_have.format) >> 3;
  int64_t raw = 0;
  double v;
  __builtin_memcpy(&raw, *in, bitsz);
  *in += bitsz;
  if (SDL_AUDIO_ISBIGENDIAN(cap_have.format))
    switch (bitsz) {
    case 2: {
      uint16_t b = __builtin_bswap16(raw);
      __builtin_memcpy(&raw, &b, 2);
    } break;
    case 4: {
      uint32_t b = __builtin_bswap32(raw);
      __builtin_memcpy(&raw, &b, 4);
    } break;
    case 8: {
      uint64_t b = __builtin_bswap64(raw);
      __builtin_memcpy(&raw, &b, 8);
    } break;
    }
  if (SDL_AUDIO_ISFLOAT(cap_have.format)) {
    if (SDL_AUDIO_BITSIZE(cap_have.format) == 32) {
      union {
        int32_t i;
        float f;
      } u = {.i = (int32_t)raw};
      v = u.f;
    } else {
      union {
        int64_t i;
        double f;
      } u = {.i = raw};
      v = u.f;
    }
  } else {
    int bits = SDL_AUDIO_BITSIZE(cap_have.format);
    int64_t peak = (1ll << (bits - 1)) - 1;
    if (!SDL_AUDIO_ISSIGNED(cap_have.format))
      raw -= peak + 1;
    else if (bits < 64 && (raw & (1ll << (bits - 1))))
      raw |= -1ll << bits; // sign-extend the narrower formats
    v = (double)raw / (double)peak;
  }
  if (v > 1.0)
    v = 1.0;
  if (v < -1.0)
    v = -1.0;
  return (int16_t)(v * 32767.0);
}

static void CaptureCB(void *ul, int8_t *in, int len) {
  (void)ul;
  int64_t frames, i;
  int c;
  if (!cap_mode)
    return;
  frames = len / cap_have.channels / (SDL_AUDIO_BITSIZE(cap_have.format) / 8);
  for (i = 0; i < frames; i++) {
    int16_t frame[8];
    for (c = 0; c < cap_have.channels && c < 8; c++)
      frame[c] = ReadSample(&in);
    if (cap_w - cap_r >= SND_CAP_BUFS)
      continue; // nobody is draining; drop rather than overwrite
    for (c = 0; c < cap_chans; c++)
      cap_ring[cap_w % SND_CAP_BUFS][cap_pos + c] =
          frame[c < cap_have.channels ? c : 0];
    cap_pos += cap_chans;
    if (cap_pos >= cap_samples) {
      cap_pos = 0;
      cap_w++;
    }
  }
}

// Open the capture device; FALSE if the host has none.
int64_t SndHostCapInit(int64_t rate, int64_t channels, int64_t buf_len) {
  SDL_AudioSpec want;
  int i;
  (void)rate;
  if (channels < 1 || channels > 8 || buf_len < channels || buf_len % channels)
    return 0;
  if (cap_mode)
    return 1;
  want = (SDL_AudioSpec){0};
  want.freq = SND_HOST_RATE;
  want.format = AUDIO_S16SYS;
  want.channels = channels;
  want.samples = 512;
  want.callback = (void *)&CaptureCB;
  capture = SDL_OpenAudioDevice(NULL, 1, &want, &cap_have,
                                SDL_AUDIO_ALLOW_FORMAT_CHANGE |
                                    SDL_AUDIO_ALLOW_CHANNELS_CHANGE);
  if (!capture)
    return 0;
  for (i = 0; i < SND_CAP_BUFS; i++) {
    if (!(cap_ring[i] = calloc(buf_len, sizeof(int16_t)))) {
      SDL_CloseAudioDevice(capture);
      capture = 0;
      return 0;
    }
  }
  cap_samples = buf_len;
  cap_chans = channels;
  cap_w = cap_r = cap_pos = 0;
  cap_mode = 1;
  SDL_PauseAudioDevice(capture, 0);
  return 1;
}

void SndHostCapRun(int64_t on) {
  if (cap_mode)
    SDL_PauseAudioDevice(capture, !on);
}

// Hand the oldest captured buffer to the caller.
int64_t SndHostCapPull(int16_t *buf) {
  if (!cap_mode || !buf || cap_r >= cap_w)
    return 0;
  memcpy(buf, cap_ring[cap_r % SND_CAP_BUFS], cap_samples * sizeof(int16_t));
  cap_r++;
  return 1;
}

static int audio_init = 0;
void InitSound() {
  SDL_AudioSpec want;
  if (0 > SDL_Init(SDL_INIT_AUDIO))
    return;
  audio_init = 1;
  want = (SDL_AudioSpec){0};
  want.freq = SND_HOST_RATE;
  want.format = AUDIO_F32;
  want.channels = 2;
  want.samples = 512;
  want.callback = (void *)&AudioCB;
  output = SDL_OpenAudioDevice(NULL, 0, &want, &have,
                               SDL_AUDIO_ALLOW_FORMAT_CHANGE |
                                   SDL_AUDIO_ALLOW_CHANNELS_CHANGE);
  SDL_PauseAudioDevice(output, 0);
}

void DeinitSound() {
  int i;
  if (!audio_init)
    return;
  SDL_PauseAudioDevice(output, 1);
  SDL_CloseAudioDevice(output);
  host_mode = 0;
  for (i = 0; i < SND_RING_BUFS; i++) {
    free(ring[i]);
    ring[i] = NULL;
  }
  if (cap_mode) {
    SDL_PauseAudioDevice(capture, 1);
    SDL_CloseAudioDevice(capture);
    cap_mode = 0;
    for (i = 0; i < SND_CAP_BUFS; i++) {
      free(cap_ring[i]);
      cap_ring[i] = NULL;
    }
  }
}
