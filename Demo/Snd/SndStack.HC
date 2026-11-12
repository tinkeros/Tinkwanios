//
// The whole sound stack in one include: the host audio device, the 8-channel
// mixer, the software OPL2 FM synthesizer, and the OPL2 front end that takes
// over Snd()/SndM()/SndRst().
//
// Afterwards every existing beep, the music DSL and all the sound demos play
// through FM synthesis instead of the one-voice host oscillator, without
// knowing anything changed -- which is the whole point of the
// snd.fp_alt_snd_dev hook.
//
#include "/Demo/Snd/HDAudio";
#include "/Demo/Snd/HDMixer";
#include "/Demo/Snd/OPL2EmuHDA";
