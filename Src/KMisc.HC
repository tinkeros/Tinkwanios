Bool LBEqu(U8 *ptr,I64 bit,Bool b) {
  if(b)
    return LBts(ptr,bit);
  return LBtr(ptr,bit);
}

U16 EndianU16(U16 d)
{//Swap big<-->little endian.
  I64 res=0;
  res.u8[1]=d.u8[0];
  res.u8[0]=d.u8[1];
  return res;
}

U32 EndianU32(U32 d)
{//Swap big<-->little endian.
  I64 res=0;
  res.u8[3]=d.u8[0];
  res.u8[2]=d.u8[1];
  res.u8[1]=d.u8[2];
  res.u8[0]=d.u8[3];
  return res;
}

I64 EndianI64(I64 d)
{//Swap big<-->little endian.
  U64 res;
  res.u8[7]=d.u8[0];
  res.u8[6]=d.u8[1];
  res.u8[5]=d.u8[2];
  res.u8[4]=d.u8[3];
  res.u8[3]=d.u8[4];
  res.u8[2]=d.u8[5];
  res.u8[1]=d.u8[6];
  res.u8[0]=d.u8[7];
  return res;
}

I64 BCnt(I64 d)
{//Count set bits in I64.
  I64 res=0,i;
  for (i=0;i<8;i++)
    res+=set_bits_table[d.u8[i]];
  return res;
}

I64 GetTSC()
{//A monotonically increasing tick count. On the metal TempleOS reads the
 //CPU's time stamp counter; here it is the host's high-precision counter,
 //which ticks microseconds -- see cnts.time_stamp_freq in KGlbls.HC.
  return __GetTicksHP;
}

F64 tS()
{//Time since boot in seconds as a float.
  return __GetTicksHP/1000000.;
}

U0 CPURep(Bool full=FALSE)
{//Report number of cores and the tick frequency.
  no_warn full;
  "%03X Cores %6h?nHz\n",mp_cnt,ToF64(cnts.time_stamp_freq);
}

Bool Blink(F64 Hz=2.5)
{//Return TRUE, then FALSE, then TRUE at given frequency.
  if (!Hz) return 0;
  return ToI64(cnts.jiffies*2*Hz/JIFFY_FREQ)&1;
}

U0 SleepUntil(I64 wake_jiffy)
{//Not for power-saving.  It is to make a program pause without hogging the CPU.
  Bool old_idle=LBts(&(Fs->task_flags),TASKf_IDLE);
  Fs->wake_jiffy=wake_jiffy;
  Yield;
  if(old_idle)
    LBts(&(Fs->task_flags),TASKf_IDLE);
  else
    LBtr(&(Fs->task_flags),TASKf_IDLE);
}

U0 Sleep(I64 mS)
{//Not for power-saving.  It is to make a program pause without hogging the CPU.
  Bool old_idle=LBts(&(Fs->task_flags),TASKf_IDLE);
  if (!mS)
    Yield;
  Fs->wake_jiffy=__GetTicks+mS;
  Yield;
  if(old_idle)
    LBts(&(Fs->task_flags),TASKf_IDLE);
  else
    LBtr(&(Fs->task_flags),TASKf_IDLE);
}

F64 Ona2Freq(I8 ona)
{//Ona to freq. Ona=60 is 440.0Hz.
  if (!ona)
    return 0;
  else
    return 440.0/32*Pow(2.0,ona/12.0);
}

I8 Freq2Ona(F64 freq)
{//Freq to Ona. 440.0Hz is Ona=60.
  if (freq>0)
    return ClampI64(12*Log2(32.0/440.0*freq),1,I8_MAX);
  else
    return 0;
}

U0 SndM(I8 ona=0,I64 chan=0)
{//Play ona, a piano key num, on a channel. 0 means rest.
 //snd.fp_alt_snd_dev is how a sound back end takes over: with one attached
 //(Demo/Snd/HDAudio.HC) tones go through the mixer, so they can be heard
 //alongside FM synthesis instead of replacing it. With none, the one-voice
 //host oscillator in c/sound.c plays it, as it always has.
  if (snd.fp_alt_snd_devM) {
//A back end taking this hook replaces SndM outright -- TinkerOS gets there
//with HijackFunc -- so it owns snd.ona/scrncast.ona too. Setting them here
//first would defeat the back end's own "is this note already playing" test.
    (*snd.fp_alt_snd_devM)(ona,chan);
    return;
  }
  snd.ona=ona;
  scrncast.ona=ona;
  if (snd.fp_alt_snd_dev)
    (*snd.fp_alt_snd_dev)(ona);
  else
    SndFreq(Ona2Freq(ona));
}

U0 Snd(I8 ona=0)
{//Play ona, a piano key num. 0 means rest.
  SndM(ona,0);
}

Bool ScrnCast(Bool val=ON,Bool just_audio=FALSE,U8 *print_fmt="T:/Video/%X.GR")
{//WinMgr saves GR files to a dir.
  Bool old_val;
  scrncast.just_audio=just_audio;
  if (val) {
    if (!(old_val=LBtr(&scrncast.record,0))) {
      Free(scrncast.print_fmt);
      scrncast.print_fmt=StrNew(print_fmt,adam_task);
      scrncast.t0_now=Now;
      scrncast.snd_head.tS=scrncast.t0_tS=tS;
      scrncast.snd_head.ona=scrncast.ona;
      LBts(&scrncast.record,0);
    }
  } else
    old_val=LBtr(&scrncast.record,0);
  Snd;
  return old_val;
}

U0 Busy(I64 uS)
{//Spin for uS microseconds without yielding -- which is the point of it,
 //and why it is not Sleep(). TempleOS counts PortNops; there is no port
 //I/O here, so this watches the high-precision tick counter instead and
 //ends up better timed than the original.
  I64 t0=__GetTicksHP;
  while (__GetTicksHP-t0<uS)
    ;
}

U0 SndRst()
{//Fix stuck sound.
  if (snd.fp_alt_snd_rst)
    (*snd.fp_alt_snd_rst)();
  else
    Snd;
}

U0 Beep(I8 ona=62,Bool busy=FALSE)
{//Make beep at given ona freq.
  Snd(ona);
  Sleep(500);
  Snd;
  Sleep(200);
}

Bool Mute(Bool val)
{//Turn-off sound.
  Bool res=FALSE;
  /* TODO RESTORE
  if (val) {
    Snd;
    res=LBts(&sys_semas[SEMA_MUTE],0);
  } else
    res=LBtr(&sys_semas[SEMA_MUTE],0);
  */
  return res;
}

Bool Mute(Bool val=ON)
{//Set mute flag, returning the old one. The sound stack checks it in
 //Demo/Snd/HDAudio.HC's pump, so muting silences the mixer too.
  return LBEqu(&sys_semas[SEMA_MUTE],0,val);
}

Bool IsMute()
{//Return is-mute flag.
  return Bt(&sys_semas[SEMA_MUTE],0);
}

Bool Silent(Bool val=ON)
{//Turn-off StdOut console text. (Not sound.)
  return LBEqu(&(Fs->display_flags),DISPLAYf_SILENT,val);
}

Bool IsSilent()
{//Return StdOut turned-off?
  return Bt(&(Fs->display_flags),DISPLAYf_SILENT);
}

Bool SysDbg(Bool val)
{//Set SysDbg bit you can use while debugging.
  //return LBEqu(&sys_semas[SEMA_DEBUG],0,val);
  return 0; //TODO RESTORE
}

Bool IsSysDbg()
{//Return SysDbg bit.
  //return Bt(&sys_semas[SEMA_DEBUG],0);
  return 0; //TODO RESTORE
}

Bool Raw(Bool val)
{//Set to direct scrn, BLACK & WHITE, non-windowed output mode.
  return 0; //TODO RESTORE
  /*if (!val)
    VGAFlush;
  return !LBEqu(&(Fs->display_flags),DISPLAYf_NOT_RAW,!val);
  */
}

Bool IsRaw()
{//Are we in BLACK & WHITE raw scrn mode?
  return IsCmdLineMode;//return !Bt(&(Fs->display_flags),DISPLAYf_NOT_RAW); TODO RESTORE
}

Bool SingleUser(Bool val)
{//Set single-user mode.
  return 0;//LBEqu(&sys_semas[SEMA_SINGLE_USER],0,val); TODO RESTORE
}

Bool IsSingleUser()
{//Return single-user mode.
  return 0; //TODO RESTORE
}

Bool DbgMode(Bool val)
{//Set dbg-mode.
  return 0; //TODO RESTORE
}

Bool IsDbgMode()
{
  return 0; //TODO RESTORE
}

U0 ProgressBarsRst(U8 *path=NULL)
{//Reset all progress bars to zero.
  ProgressBarsRegTf(path);
  MemSet(sys_progresses,0,4*sizeof(CProgress));
}


#help_index "Bitfields"
public Bool BEqu(U8 *ptr,I64 bit,Bool b)
{//Set bit to b, returning its old value.
  if (b)
    return Bts(ptr,bit);
  else
    return Btr(ptr,bit);
}

public U0 BitFieldSet(U8 *bit_field,U8 bit_offset,U8 size,U8 value)
{//Sets values in a bit field. ('offset' is a keyword, hence bit_offset.)
  I64 i;
  for (i=0;i<size;i++)
    BEqu(bit_field,bit_offset+i,value>>i);
}

public U64 BitFieldGet(U8 *bit_field,U8 bit_offset,U8 size)
{//Gets values from a bit field
  I64 i;
  U64 val=0;
  for (i=0;i<size;i++)
    BEqu(&val,i,Bt(bit_field,bit_offset+i));
  return val;
}

#help_index "Memory/Class"
public U0 ZeroClass(U8 *ptr,I64 s_elem=firstsize)
{//Set all data in a class to zero. s_elem defaults to sizeof the 1st arg.
  MemSet(ptr,0,s_elem);
}

public U0 ClassCpy(U8 *dst,U8 *src,I64 n_elem=1,I64 s_elem=firstsize)
{//Copy n_elem elements of a class onto another, fixed or heap array alike.
  MemCpy(dst,src,n_elem*s_elem);
}

public U0 ArrayZero(U8 *ptr,I64 n_elem,I64 s_elem=firstsize)
{//Zero n_elem elements of class ptr, fixed or heap array alike.
  MemSet(ptr,0,n_elem*s_elem);
}

public Bool ArrayMAlloc(U8 **ptr,I64 n_elem,I64 s_elem=firstsize)
{// Alloc array of class ptr elements
  *ptr=MAlloc(n_elem*s_elem);
  if (*ptr) return TRUE;
  return FALSE;
}

public Bool ArrayCAlloc(U8 **ptr,I64 n_elem,I64 s_elem=firstsize)
{// CAlloc array of class ptr elements
  *ptr=CAlloc(n_elem*s_elem);
  if (*ptr) return TRUE;
  return FALSE;
}

public U8 *ReAlloc(U8 *ptr,I64 size=firstsize)
{//Grow or shrink an allocation, copying the old contents across.
  U8 *ptr2=MAlloc(size);
  if (!size && ptr) Free(ptr);
  if (ptr2) {
    MemCpy(ptr2,ptr,size);
    Free(ptr);
    return ptr2;
  }
  return 0;
}

public Bool ArrayReAlloc(U8 **ptr,I64 n_elem,I64 s_elem=firstsize)
{// ReAlloc array of class ptr elements
  U8 *n_ptr=ReAlloc(*ptr,n_elem*s_elem);
  if (!n_ptr) return FALSE;
  *ptr=n_ptr;
  return TRUE;
}

public I64 ArraySize(U8 *ptr,I64 s_elem=firstsize)
{//How many elements the allocation behind ptr can hold.
  if (ptr) return MSize(ptr)/s_elem;
  return 0;
}

public U0 KeyStateRst()
{//Clears state of all keys in key_state and sc_state. Worth calling before
 //reading them: an UP message can be lost while a task is not focused.
  MemSetI64(key_state,0,16);
  MemSetI64(sc_state,0,32);
  sc_flags_state=0;
}

public U0 VGAFlush()
{//Flush the screen cache so the next update redraws all of it. On the metal
 //this is how a palette change or a direct poke at video memory is made to
 //show; here the whole frame is pushed to the host every refresh anyway, so
 //all it has to do is be callable -- several demos ask for it.
  LBts(&sys_semas[SEMA_FLUSH_VGA_IMAGE],0);
}
