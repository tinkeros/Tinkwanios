#help_index "Snd/HDAudio"
//
// The sound device the rest of Demo/Snd renders into.
//
// On TinkerOS this file drives a real Intel HD Audio controller: it walks
// PCI, configures a codec, and points two DMA buffers at the output stream.
// Everything above it -- the mixer, the OPL2 FM synthesizer, Wav, Mp3 --
// only ever touches fp_snd_fill_buf and the SND_* constants, so here that
// bottom layer is the host's audio device instead (see c/sound.c) and the
// stack above ports across unchanged.
//
// What is kept identical to TinkerOS on purpose: the constants, the
// fp_snd/fp_snd_fill_buf globals, snd_dev/snd_vol/snd_obuf_num, and the
// double-buffered pump task. What is gone: the codec verbs, the PCI probe,
// and recording, none of which have a counterpart here.
//
// Load this, then Demo/Snd/HDMixer.HC, then Demo/Snd/OPL2EmuHDA.HC, then
// Demo/Snd/OPL2.HC -- or just Demo/Snd/SndStack.HC, which does all four.
//

#define SD_PC_SPEAKER		0
#define SD_HD_AUDIO		1

#define SND_SAMPLE_RATE		48000
#define SND_SAMPLE_BITS		32
#define SND_OCHANNELS		2
#define SND_ICHANNELS		2
#define SND_OUT_CONTAINER	I32
#define SND_IN_CONTAINER	I16
#define SND_BUF_LEN		0x800
#define SND_BUF_TIME_mS		(SND_BUF_LEN/SND_OCHANNELS*1000.0/\
				SND_SAMPLE_RATE)

F64 snd_freq=0;
I64 snd_dev=SD_PC_SPEAKER;
Bool snd_record=FALSE;
F64 snd_vol=1.0;
U0 (*fp_snd)(F64 freq,I64 waveform,F64 amp)=NULL;
U0 (*fp_snd_record)(F64 freq,I64 waveform,F64 amp)=NULL;
U0 (*fp_snd_fill_buf)(SND_OUT_CONTAINER *buf,I64 buf_num)=NULL;
U0 (*fp_snd_copy_buf)(SND_IN_CONTAINER *buf,I64 buf_num)=NULL;

I64 snd_obuf_num,snd_ibuf_num;

#define Sf_FILLING_OUT		0
I64 snd_flags;

#define HD_TONES		4

#define HD_WAVE_SQUARE		0
#define HD_WAVE_SINE		1
#define HD_WAVE_TRIANGLE	2
#define HD_WAVE_SAWTOOTH	3

//One voice. freq_multiplier/amp_multiplier are TempleOS's CSndWaveCtrl
//knobs, kept under those names because that is how TinkerOS's demos drive
//the voices: HDAudioChords.HC detunes voices 1 and 2 by 4/3, and
//HDAudioGuitar.HC stacks HD_TONES harmonics with a decaying amplitude.
class CHDTone
{
  F64 freq_multiplier,amp_multiplier,phase;
  I64 waveform;
};

class CHDAudio
{
  CHDTone tones[HD_TONES];
//Demos reach the voices through here, as they do on TinkerOS.
  CHDTone *tone_swcs[HD_TONES];
  F64 freq,amp;
  I64 waveform;
  Bool started;
  CTask *task;
//Two output buffers, alternated, so something reading the last one filled
//(HDAudioSndScope.HC) is not looking at the buffer being written.
  SND_OUT_CONTAINER *ostr0_buf[2];
  I64 buf_idx;
//And two input buffers, same idea, filled from the host capture ring.
//HDAudioEcho.HC reads istr0_buf[0] to draw the incoming waveform.
  SND_IN_CONTAINER *istr0_buf[2];
  I64 ibuf_idx;
  Bool cap_up;
} hda;

F64 HDWave(I64 waveform,F64 ph)
{//One cycle of a waveform, ph in 0.0-1.0.
  switch (waveform) {
    case HD_WAVE_SINE:
      return Sin(2*pi*ph);
    case HD_WAVE_TRIANGLE:
      if (ph<0.5)
	return 4.0*ph-1.0;
      return 3.0-4.0*ph;
    case HD_WAVE_SAWTOOTH:
      return 2.0*ph-1.0;
  }
  if (ph<0.5)
    return 1.0;
  return -1.0;
}

U0 HDFillBuf(SND_OUT_CONTAINER *buf,I64 buf_num)
{//The tone voices, as one mixer source. Stands in for TinkerOS's
 //SndWaveCtrl-driven version; same shape, simpler oscillators.
  I64 i,j,t,frames=SND_BUF_LEN/SND_OCHANNELS;
  F64 mix,inc,freq,amp;
  CHDTone *tone;
  no_warn buf_num;
  for (i=0;i<frames;i++) {
    mix=0.0;
    for (t=0;t<HD_TONES;t++) {
      tone=&hda.tones[t];
      freq=hda.freq*tone->freq_multiplier;
      amp =hda.amp *tone->amp_multiplier;
//HolyC has no 'continue'.
      if (freq>0.0 && amp>0.0) {
	inc=freq/SND_SAMPLE_RATE;
	tone->phase+=inc;
	while (tone->phase>=1.0)
	  tone->phase-=1.0;
	mix+=HDWave(tone->waveform,tone->phase)*amp;
      }
    }
    mix*=snd_vol*0.25;
    t=ToI64(Clamp(mix,-1.0,1.0)*I32_MAX)&0xFFFFFF00;
    for (j=0;j<SND_OCHANNELS;j++)
      buf[i*SND_OCHANNELS+j]=t;
  }
}

U0 HDSnd(F64 freq,I64 waveform,F64 amp)
{//Set the base frequency every voice is a multiple of. Matches TinkerOS's
 //fp_snd signature.
  I64 i;
  hda.freq=freq;
  hda.waveform=waveform;
  hda.amp=amp;
  for (i=0;i<HD_TONES;i++) {
    hda.tones[i].waveform=waveform;
    if (freq<=0.0)
      hda.tones[i].phase=0.0;
  }
}

U0 HDAltSndDev(I64 ona)
{//snd.fp_alt_snd_dev: this is how Snd()/SndM() and the music DSL reach the
 //mixer rather than the one-voice host oscillator.
  if (!ona)
    HDSnd(0.0,HD_WAVE_SQUARE,0.0);
  else
    HDSnd(Ona2Freq(ona),HD_WAVE_SQUARE,1.0);
}

U0 HDAudioTask(U8 *)
{//Fill buffers while the host ring has room, then wait. The ring is what
 //paces this: SndHostFree() falls to zero once we are a few buffers ahead.
  I64 i;
  SND_OUT_CONTAINER *buf;
  for (i=0;i<2;i++) {
    hda.ostr0_buf[i]=AMAlloc(SND_BUF_LEN*sizeof(SND_OUT_CONTAINER));
    hda.istr0_buf[i]=AMAlloc(SND_BUF_LEN*sizeof(SND_IN_CONTAINER));
    MemSet(hda.istr0_buf[i],0,SND_BUF_LEN*sizeof(SND_IN_CONTAINER));
  }
  hda.buf_idx=0;
  hda.ibuf_idx=0;
  hda.started=TRUE;
  while (TRUE) {
    if (SndHostFree) {
      buf=hda.ostr0_buf[hda.buf_idx];
      if (fp_snd_fill_buf) {
	LBts(&snd_flags,Sf_FILLING_OUT);
	(*fp_snd_fill_buf)(buf,snd_obuf_num);
	LBtr(&snd_flags,Sf_FILLING_OUT);
      } else
	MemSet(buf,0,SND_BUF_LEN*sizeof(SND_OUT_CONTAINER));
      if (IsMute)
	MemSet(buf,0,SND_BUF_LEN*sizeof(SND_OUT_CONTAINER));
      SndHostPush(buf);
      hda.buf_idx=hda.buf_idx^1;
      snd_obuf_num++;
    } else
      Sleep(ToI64(SND_BUF_TIME_mS)/2+1);
//Drain the capture ring in the same loop. On TinkerOS this is driven by the
//input stream's DMA position; here a buffer either is ready or is not.
    if (hda.cap_up) {
      if (SndHostCapPull(hda.istr0_buf[hda.ibuf_idx])) {
	if (fp_snd_copy_buf)
	  (*fp_snd_copy_buf)(hda.istr0_buf[hda.ibuf_idx],snd_ibuf_num);
	hda.ibuf_idx=hda.ibuf_idx^1;
	snd_ibuf_num++;
      }
    }
  }
}

public U0 HDTonesInit()
{//Silence every voice but the first, and point tone_swcs[] at them.
  I64 i;
  for (i=0;i<HD_TONES;i++) {
    hda.tones[i].freq_multiplier=1.0;
    hda.tones[i].amp_multiplier=0.0;
    hda.tones[i].phase=0.0;
    hda.tones[i].waveform=HD_WAVE_SQUARE;
    hda.tone_swcs[i]=&hda.tones[i];
  }
  hda.tones[0].amp_multiplier=1.0;
}

public U0 HDStop(Bool in=TRUE,Bool out=TRUE)
{//Stop the input and/or output stream, as TinkerOS's does. Demos say
 //HDStop(TRUE,FALSE) to silence the microphone and keep playing, so the two
 //halves have to be independent. Stopping the output hands the device back
 //to the plain host oscillator.
  if (in && hda.cap_up)
    SndHostCapRun(FALSE);
  if (!out || snd_dev!=SD_HD_AUDIO)
    return;
  HDSnd(0.0,HD_WAVE_SQUARE,0.0);
  if (snd.fp_alt_snd_dev==&HDAltSndDev)
    snd.fp_alt_snd_dev=NULL;
  snd_dev=SD_PC_SPEAKER;
  if (hda.task) {
    Kill(hda.task);
    hda.task=NULL;
  }
}


public Bool HDAudioInit()
{//Open the host device and start the pump.
  if (snd_dev==SD_HD_AUDIO)
    return TRUE;
  HDTonesInit;
  if (!SndHostInit(SND_SAMPLE_RATE,SND_OCHANNELS,SND_BUF_LEN)) {
    "HD Audio: no host audio device.\n";
    return FALSE;
  }
  snd_obuf_num=1;
  snd_ibuf_num=1;
  fp_snd=&HDSnd;
  fp_snd_fill_buf=&HDFillBuf;
  fp_snd_copy_buf=NULL;
  snd_dev=SD_HD_AUDIO;
  snd.fp_alt_snd_dev=&HDAltSndDev;
  hda.task=Spawn(&HDAudioTask,NULL,"HD Audio",,adam_task);
  while (!hda.started)
    Yield;
  return TRUE;
}

public Bool HDRecordInit()
{//Open the host's capture device. FALSE if the host has none, which is a
 //normal thing to be told rather than an error.
  if (hda.cap_up)
    return TRUE;
  if (!SndHostCapInit(SND_SAMPLE_RATE,SND_ICHANNELS,SND_BUF_LEN)) {
    "HD Audio: no host capture device, recording unavailable.\n";
    return FALSE;
  }
  hda.cap_up=TRUE;
  return TRUE;
}

public U0 HDRun(Bool in=TRUE,Bool out=TRUE)
{//The other half of HDStop(). Starting the output is HDAudioInit().
  if (out && snd_dev!=SD_HD_AUDIO)
    HDAudioInit;
  if (in) {
    if (HDRecordInit)
      SndHostCapRun(TRUE);
  }
}

if (HDAudioInit)
  "HD Audio loaded (%d Hz, %d ch, %5.2f mS buffers).\n",
	SND_SAMPLE_RATE,SND_OCHANNELS,SND_BUF_TIME_mS;

#help_index ""
