//
// The sound stack plus every source that registers with the mixer: the host
// device, the 8-channel mixer, OPL2 FM, and the Wav / TTS / MP3 players.
//
// /Demo/Snd/SndStack.HC on its own gives you sound; this adds the players, so
// the mixer GUI (<CTRL-ALT-M>, see /Demo/Snd/HDMixerGui.HC) comes up with a
// fader and test links per source rather than just Master.
//
// Include it from the task you want to keep the mixer in -- the GUI spawns as
// a child of that task and compiles its test links against its symbols.
//
#include "/Demo/Snd/SndStack";
#include "/Demo/Snd/OPL2";
#include "/Demo/Snd/Wav";
#include "/Demo/Snd/TTS";
#include "/Demo/Snd/Mp3";
