#include "Kernel/KernelA.HH"
#ifdef BOOTSTRAP
#define mp_cnt 1
#endif
#include "Compiler/CompilerA.HH"
#include "Compiler/CExts.HC"
#include "Compiler/CompilerB.HH"
#include "Kernel/KGlbls.HC"
//Must precede every use of GR_WIDTH/GR_HEIGHT, KMain.HC's text layer first.
gr_width=GrWidthGet;
gr_height=GrHeightGet;
gr_width_scale=GrWidthScaleGet;
gr_height_scale=GrHeightScaleGet;
gr_do_scaling=GrDoScalingGet;
fb_width=FBWidthGet;
fb_height=FBHeightGet;
#include "Kernel/KMisc.HC"

CCPU cpu_structs[64];
SetGs(&cpu_structs[0]);
//TINKWANIOS Boot stuff
U8 *StrNew(U8 *str,CTask *task=NULL) {
  if(task) {
//Heap?
    if(task->task_signature.u8[0]=='H') {
      task=task;
      goto do_it;
    }
  }
  if(task)
    task=task->data_heap;
  else
    task=Fs->data_heap;
do_it:
  if(!str) str="";
  return __StrNew(str,task);
}
U8 *MAlloc(I64 cnt,CTask *task=NULL) {
  U8 *hc;
  CMemUnused *m;
  if(task) {
//Heap?
    if(task->task_signature.u8[0]=='H') {
      hc=task;
      goto do_it;
    }
  }
  if(task)
    hc=task->data_heap;
  else
    hc=Fs->data_heap;

do_it:
  m=__MAlloc(cnt,hc);
  if(m) {
    m[-1].caller1=Caller(2);
    m[-1].caller2=Caller(3);
  }
  return m;
}
U8 *CAlloc(I64 cnt,CTask *task=NULL) {
  U8 *hc;
  CMemUnused *m;
  if(task) {
//Heap?
    if(task->task_signature.u8[0]=='H') {
      hc=task;
      goto do_it;
    }
  }  if(task)
    hc=task->data_heap;
  else
    hc=Fs->data_heap;
do_it:
  m=__CAlloc(cnt,hc);
  if(m) {
    m[-1].caller1=Caller(2);
    m[-1].caller2=Caller(3);
  }
  return m;
}
U8 *AStrNew(U8 *str) {
  return StrNew(str,adam_task);
}
U8 *AMAlloc(I64 cnt,CTask *task=NULL) {
  return MAlloc(cnt,adam_task);
}
U8 *ACAlloc(I64 cnt) {
  return CAlloc(cnt,adam_task);
}
U8 *MAllocIdent(U8 *ptr,CTask *task=NULL) {
  CMemUnused *hc,*ret;
  I64 cnt=MSize(ptr);
  if(task) {
//Heap?
    if(task->task_signature.u8[0]=='H') {
      hc=task;
      goto do_it;
    }
  }  if(task)
    hc=task->data_heap;
  else
    hc=Fs->data_heap;
do_it:
  ret=__MAlloc(cnt,hc);
  MemCpy(ret,ptr,cnt);
  if(ret) {
    ret[-1].caller1=Caller(2);
    ret[-1].caller2=Caller(3);
  }
  return ret;
}

U8 *AMAllocIdent(U8 *ptr) {
  return MAllocIdent(ptr,adam_task);
}

U8 *MAllocAligned(I64 size,I64 alignment,
       CTask *mem_task=NULL,I64 misalignment=0)
{//Only powers of two alignment. This is awful.
  I64 mask=alignment-1;
  U8 *ptr=MAlloc(size+mask+sizeof(I64)+misalignment,mem_task),
       *res=(ptr+sizeof(I64)+mask)&~mask+misalignment;
  res(I64 *)[-1]=ptr-res;
  return res;
}

CTask *tinkwanios_boot_task=__CAlloc(sizeof CTask);
extern U0 Print(U8*,...);

U0 SwapU8(U8 *a,U8 *b) {
  U8 tmp=*a;
  *a=*b;
  *b=tmp;
}

U0 SwapU16(U16 *a,U16 *b) {
  U16 tmp=*a;
  *a=*b;
  *b=tmp;
}

U0 SwapU32(I32 *a,I32 *b) {
  I32 tmp=*a;
  *a=*b;
  *b=tmp;
}

U0 SwapI64(I64 *a,I64 *b) {
  I64 tmp=*a;
  *a=*b;
  *b=tmp;
}
#include "Src/CQue.HC"
#include "Kernel/KDate.HC"
#include "Kernel/StrA.HC"
#include "Kernel/KHashA.HC"
#include "Src/KMath.HC"
#include "Kernel/KMathB.HC"
#include "Kernel/StrPrint.HC"
#include "Kernel/StrA.HC"
#include "Kernel/Sched.HC"
#include "Kernel/Display.HC"
#include "Kernel/KHashB.HC"
#include "Kernel/KTask.HC"
#include "Kernel/MultiProc.HC"
#include "Kernel/KExcept.HC"
#include "Kernel/Job.HC"
#include "Kernel/KDataTypes.HC"
#include "Kernel/Compress.HC"
#include "Kernel/StrB.HC"
#include "Kernel/KDefine.HC"
#include "Kernel/StrScan.HC"
#include "Compiler/QSort.HC"
#include "Kernel/BlkDev/MakeBlkDev.HC"
adam_task=tinkwanios_boot_task;
SetFs(adam_task);
TaskInit(adam_task,0);
#include "Src/KEnd.HC"
#include "Kernel/FontStd.HC"
#include "Kernel/FontCyrillic.HC"
#include "Kernel/KLoadARM.HC"
#include "Kernel/FunSeg.HC"
#include "Src/Compiler.HC"
#include "Kernel/KeyDev.HC"
#include "Kernel/SerialDev/Keyboard.HC"
#include "Kernel/SerialDev/Message.HC"
#include "Kernel/SerialDev/Mouse.HC"
#include "Kernel/EdLite.HC"
#include "Adam/Opt/Utils/Profiler.HC"
#ifdef TARGET_X86
#include "Src/UAsmX64.HC"
#include "Compiler/AsmX64.HC"
#endif
#ifdef TARGET_RISCV
#include "Src/UAsmRiscV.HC"
#include "Compiler/AsmRISCV.HC"
#endif
#include "Kernel/KUtils.HC"
#include "Kernel/KMain.HC"
//IMPORTANT:DO NOT CHANGE ORDER OF KMAIN WITH ARM
#ifdef TARGET_AARCH64
#include "Src/UAsmARM64.HC"
#include "Compiler/AsmARM64.HC"
#endif

U0 SCRoutine() {
  SetFs(adam_task);//For Caller
  CTask *self=CAlloc(sizeof CTask,adam_task);
  SetFs(self);
  TaskInit(Fs,0);
  Fs->task_signature=TASK_SIGNATURE_VAL;
//Chain this core's Seth task onto Adam, the way core 0's already is --
//InitCPUs sets cpu_structs[0].seth_task=adam_task outright. Spawn() parents a
//task to Gs->seth_task when no parent is given, and a task can only compile
//what its parent's hash table chain reaches (see Spawn's "NULL means adam"
//comment, and KTask.HC's hash_table->next line). Without this an AP core's
//tasks reached nothing: Demo/MultiCore/LoadTest.HC's Spawn(&Job1,,,1) could
//not resolve Cmp, HashFind or StreamPrint, so its compile workload failed
//instantly and silently under its own Silent;.
  Fs->parent_task=adam_task;
  Fs->hash_table->next=adam_task->hash_table;
  Gs->seth_task=Fs;
  LBts(&(Gs->ready),0);
  CoreAPSethTask;
}
U0 InitCPUs() {
  I64 idx;
  MemSet(&cpu_structs,0,sizeof(CCPU) *64);
  cpu_structs[0].addr=&cpu_structs[0];
  cpu_structs[0].seth_task=adam_task;
  //See MultiProc.HC
  CCPU *c=&cpu_structs;
  c->addr=c;
  c->num=0;
  c->idle_factor=0.01;
  QueInit(&c->next_dying);
  adam_task->gs=c;
  adam_task->task_signature=TASK_SIGNATURE_VAL;
  //cpu_structs[0].seth_task=Spawn(&CoreAPSethTask,,,,adam_task,,0); //TODO
  for(idx=1;idx<mp_cnt;idx++) {
    c=&cpu_structs[idx];
    c->addr=c;
    c->num=idx;
    c->idle_factor=0.01;
    QueInit(&c->next_dying);
    SpawnCore(&SCRoutine,c,idx);
    do PAUSE
    while (!Bt(&c->ready,0));
  }
 }
InitCPUs;
#ifndef NO_BOOT
SetFs(Gs->seth_task);
#endif
#ifdef STAGE1
#ifndef BOOTSTRAP
//Embed them so the user cant mess it up
U8 *KernelAHH;
//Seperate to avoid weird bug with running #exe block twice
KernelAHH=(#exe {ExeEmbedFile("/Kernel/KernelA.HH");});;
//Gr.HH too, for CSprite. The compiler consumes it while building this
//binary, so without replaying it the class exists in the compiled code but
//not in the runtime hash table, and user code gets the forward declaration
//in KernelA.HH -- which has no members. See InitSymbols below.
U8 *GrHH;
GrHH=(#exe {ExeEmbedFile("/Adam/Gr/Gr.HH");});;
#endif
#endif
//For use later(ABOVE)
U0 ExeEmbedFile(U8 *fn) {
//During Tinkwanios bootstapping,only Functions  are imported and not macros
  DbgPrint("Embedding File \"%Q\"(may take some time)\n",fn);
  U8 *ptr,*buf,*ptr2;
  CArcCompress *comp;
  I64 len,len2,b;
  ptr=FileRead(fn,&len);
  comp=CompressBuf(ptr,len+1); //+1 for NULL terminator
  Free(ptr);
  ptr=comp;
	len=comp->compressed_size;
  ptr2=buf=MAlloc(4*len+1); //\xff(4 chars )
  StreamPrint("ExpandBuf(");
  while(len>0) {
    StrPrint(ptr2,"\\x%02x",*ptr++);
    ptr2+=4;
    len--;
  }
  *ptr2=0;
  StreamPrint("\"%s\"\n",buf);
  StreamPrint(")");
  Free(comp);
}

U0 ImportSymbolsCB(U8 *name,U8 *addr) {
  CHashExport *find=HashFind(name,Fs->hash_table,-1);
  I64 cnt=1;
  if(find&&find->type&HTT_GLBL_VAR) {
    find(CHashGlblVar*)->data_addr=addr;
  } else if(find&&find->type&HTT_FUN) {
    if(!(find(CHashFun*)->flags&1<<Ff_INTERNAL)) {
      find(CHashFun*)->exe_addr=addr;
      LBtr(&find(CHashFun*)->flags,Cf_EXTERN);
    }
  } 
  #ifdef GEN_HEADERS
  else if(1) {
    DocPrint(unfound,"%s\n",name);
  }
  #endif
  else {
    find=CAlloc(sizeof(CHashExport),adam_task);
    find->str=AStrNew(name);
    find->type=HTT_EXPORT_SYS_SYM;
    find->val=addr;
    HashAdd(find,Fs->hash_table);
  }
}
#ifdef GEN_HEADERS
CDoc *unfound=DocNew("unfound.DD");
#endif
U0 InitSymbols() {
#ifdef TARGET_BYTECODE
  ExePrint("#define TARGET_BYTECODE\n;");
#endif
#ifdef TARGET_X86
  ExePrint("#define TARGET_X86\n;");
#endif
#ifdef TARGET_AARCH64
  ExePrint("#define TARGET_AARCH64\n;");
#endif
#ifdef TARGET_RISCV
  ExePrint("#define TARGET_RISCV\n;");
#endif
//HOST_ABI alongside the targets, so runtime-compiled code can see which host
//ABI this binary was built for. It is a build-time define (c/main.c's
//BOOTSTRAP_FMT, and the STAGE1 body below) and was reachable nowhere else at
//runtime, so a standalone compile of CMain.HC or KDbg.HC -- both of which
//test HOST_ABI=='OpenBSD' -- could not be made to work. That is what
//Compiler/Compiler.PRJ needs. Emitted as the integer the multi-character
//constant already is, so HOST_ABI=='OpenBSD' still compares correctly.
  ExePrint("#define HOST_ABI %d\n;",HOST_ABI);
#ifdef STAGE1
  ExePutS(KernelAHH,"/Kernel/KernelA.HH");
//After KernelA.HH: Gr.HH's 19 sprite/mesh classes are also declared there
//and redeclaring them identically is a no-op, while CSprite -- which only
//Gr.HH has in full -- becomes resolvable to user code. Gr.HH is pure class
//and #define text with no executable statement and no reference to 'gr',
//so it is safe this early, unlike a default argument of gr.dc.
  ExePutS(GrHH,"/Adam/Gr/Gr.HH");
  ImportSymbolsToHolyC(&ImportSymbolsCB);
  if(FileFind("/HCRT2.DBG.Z")) DbgInfoRead("/HCRT2.DBG.Z");
#else
//BOOTSTRAP is defined
  ExeFile("T:/Kernel/KernelA.HH");
  ImportSymbolsToHolyC(&ImportSymbolsCB);
#endif
  #ifdef GEN_HEADERS
  DocWrite(unfound);
  DocDel(unfound);
  #endif
}
InitSymbols;

#ifdef BOOTSTRAP
//Stage 2 compiles with the cwd left at the repo root, not at Src. The HolyC
//compiler resolves #include against the cwd while the C bootstrap in c/lex.c
//resolves it against the including file's directory; spelling every include
//from the root ("Kernel/KGlbls.HC", "Adam/DolDoc/DocExt.HC") is the one
//spelling both agree on now that the tree mirrors TinkerOS's layout. c/lex.c
//falls back to the cwd for the nested aggregators, whose own directory is not
//the root. Cd("Src") here would break every root-relative include below.
U8 *body=
	MStrPrint("#define IMPORT_TINKWANIOS_SYMS 1\n"
	"#define TEXT_MODE 0\n"
	#ifdef TARGET_X86
	"#define TARGET_X86 1\n"
	#endif
	#ifdef TARGET_BYTECODE
	"#define TARGET_BYTECODE 21\n"
	#endif
	#ifdef TARGET_AARCH64
	"#define TARGET_AARCH64 1\n"
	#endif
	#ifdef TARGET_RISCV
	"#define TARGET_RISCV 1\n"
	#endif
	"#define HOST_ABI '%c'\n"
	"#define STAGE1 1\n"
	"#include \"Src/HCRT_TOS.HC\";;\n",
	HOST_ABI
);
//Put this in a scope to do this all at once
{
	FileWrite("Src/STAGE1.HC",body,StrLen(body));
	Cmp("Src/STAGE1.HC","HCRT2.DBG.Z","HCRT2.BIN");
	ExitTinkwanios;
}
#endif
#ifdef COMPONET_GR
#include "Kernel/ABlkDev/ADskA.HC"
#include "Kernel/ABlkDev/ADskB.HC"
#include "Adam/Gr/MakeGr.HC"
#include "Adam/Menu.HC"
#include "Adam/Win.HC"
#include "Adam/WinMgr.HC"
#include "Adam/God/GodExt.HC"
#include "Adam/DolDoc/MakeDoc.HC"
#include "Adam/Gr/GrMisc.HC"
#include "Adam/Training.HC"
#include "Adam/AutoComplete/MakeAC.HC"
#include "Kernel/ABlkDev/Mount.HC"
#include "Adam/God/MakeGod.HC"
#include "Adam/Snd/ASnd.HC"
#include "Adam/TaskSettings.HC"
#include "Adam/Ctrls/MakeCtrls.HC"
#include "Adam/Utils.HC"
#include "Adam/ABlkDev/FileMgr.HC"
#include "Kernel/KDbg.HC"
#include "Adam/ADbg.HC"
#include "Adam/ARegistry.HC"
#include "Compiler/CHash.HC"
#include "Adam/AHash.HC"
#include "Adam/AMath.HC"
#include "Adam/AMathODE.HC" 
#include "Adam/InFile.HC" 
#include "Adam/Opt/Utils/AdamLite.HC"
#include "Adam/TaskRep.HC"
#include "Adam/Opt/Utils/Diff.HC" 
#include "Adam/Opt/Utils/Merge.HC" 
#include "Adam/Opt/Utils/DocUtils.HC" 
#include "Adam/Opt/Boot/MakeISOFile.HC"
#include "Adam/Opt/Utils/LineRep.HC"
#include "Adam/Opt/Utils/LinkChk.HC"
#include "Adam/Opt/Utils/FileBMP.HC"
#include "Adam/Opt/Utils/StrUtils.HC"
#include "Adam/Opt/Utils/Reports.HC"
#include "Adam/Gr/GrPaint.HC"
if(!IsCmdLineMode&&!IsCmdLineMode2)
  DrawWindowNew;
text.fb_alias=FBAliasGet;
sys_vbe_mode_pitch=FBPitchGet; //Only valid once DrawWindowNew has made the surface.
#ifdef GEN_HEADERS
#include "Src/GenHeader.HC";;
#endif
Gs->seth_task=adam_task;
if(IsCmdLineMode2)
  TinkwaniosTUIEnable;

if(!IsCmdLineMode)
  sys_winmgr_task=Spawn(&WinMgrTask,NULL,"Window Mgr");
if(sys_winmgr_task)
  SetWinMgrFlags(&sys_winmgr_task->task_flags);
U0 UserStartUp()
{//Run each time a user a spawned
  DocTermNew;
  Type("::/Doc/Start.DD");
  LBts(&(Fs->display_flags),DISPLAYf_SHOW);
  WinToTop;
  WinZBufUpdate;
  //Dir;
  //"$TX,"",D="DD_TEMPLEOS_LOC"$LOC:";
  //CPURep;
}
PaletteSetStd;
U8 *_CmdLineGetStr(U8 *st) {
  U8 *ret,*dc=DirCur,*pmt=MStrPrint("%s> ",dc);
  ret=CmdLineGetStr(pmt); 
  Free(dc),Free(pmt);
  return ret;
}
U0 Exit0() {
  ExitTinkwanios(0);
}
//Kinds of command line boot file, from BootFileKindOf in c/main.c. The paths
//in CmdLineBootFiles are already relative to the boot drive, so a host path
//like /home/ubuntu/github/Aiwnios/Demo/FirstSize.HC arrives here as
///Demo/FirstSize.HC.
#define BOOT_FILE_INCLUDE 0
#define BOOT_FILE_EDIT    1
U0 CmdLine(I64) {
  CTask *cmd_line;
  I64 cnt=0,old=-1;
  Fs->task_end_cb=&Exit0;
  for(cnt=0;cnt!=CmdLineBootFileCnt;cnt++)
    if (CmdLineBootFileKinds[cnt]==BOOT_FILE_EDIT)
     ExePrint2("Ed(\"%s\");;",CmdLineBootFiles[cnt]);
    else
     ExePrint2(
//TRick into thinking it is a valid CMD_LINE
       "Fs->last_cc->flags|=CCF_CMD_LINE;"
       "#include \"%s\";;",CmdLineBootFiles[cnt]);
  if (CmdLineBootFileCnt)
    ExePrint2("Exit;\n");
  Fs->task_end_cb=NULL;
//
//  Properly handle __CMD_LINE__
//
  Spawn(&UserCmdLine)->task_end_cb=&Exit0;
}
#include "Src/TinkwaniosPack.HC";
TinkwaniosPackLoad; //Does nothing if not tinkwanios-packed
//Compiled at runtime, not #included: stage 1 is the C compiler in c/ and
//it has no "asm" keyword, so an asm block anywhere in the AOT build dies
//with ERR:...Unknown symbol 'asm' (and the build still exits 0).
//Before the cmd-line/GUI split so -c gets the entry points too.
ExePrint2("#include \"~:/Src/StrAsm.HC\";;");
U0 CmdLineBootFilesToUser(CTask *task)
{//Feed the files named on the command line to a user terminal, as if typed.
 //The cmd line mode equivalent is the loop in CmdLine above.
  I64 cnt;
//XTalk, not XTalkWait: a demo or an editor keeps the task busy for as long
//as the user wants it, and waiting here would stall the rest of boot.
  for(cnt=0;cnt!=CmdLineBootFileCnt;cnt++)
    if (CmdLineBootFileKinds[cnt]==BOOT_FILE_EDIT)
      XTalk(task,"Ed(\"%s\");\n",CmdLineBootFiles[cnt]);
    else
      XTalk(task,"#include \"%s\";\n",CmdLineBootFiles[cnt]);
}
CTask *boot_user_task=NULL;
if(IsCmdLineMode) {
  fp_getstr2=&_CmdLineGetStr;
  Spawn(&CmdLine);
  CoreAPSethTask;
} else {
  boot_user_task=User;
  WinMax(boot_user_task);
}
if(!IsCmdLineMode) {
  ExePrint2("#include \"~:/Adam/WallPaper.HC\";WallPaperInit;;");
  ExePrint2("#include \"~:/Adam/AMouse.HC\";");
  if (_SixtyFPS)
    SetFPS(60.);

//The OS source is spread over four directories now (Adam, Compiler, Kernel
//and what is left of Src), and a FilesFind mask descends from one root only.
//ACInit resets the hash table, so only the first call can be ACInit; the rest
//add to it directly, under the same ACf_INIT_IN_PROGRESS bit ACInit takes --
//AutoComplete's own task waits on it (ACTask.HC) and is already ON by then.
#ifndef TARGET_BYTECODE
  ACInit("~:/Kernel/*.HC*;*.HH*");
  while (LBts(&ac.flags,ACf_INIT_IN_PROGRESS))
    Yield;
  ACMainFileLstTraverse("~:/Adam/*.HC*;*.HH*");
  ACMainFileLstTraverse("~:/Compiler/*.HC*;*.HH*");
  ACMainFileLstTraverse("~:/Src/*.HC*;*.HH*");
  LBtr(&ac.flags,ACf_INIT_IN_PROGRESS);
#endif
#ifdef TARGET_BYTECODE
  ACInit("~:/Kernel/*.HH*;*.HH*");
  while (LBts(&ac.flags,ACf_INIT_IN_PROGRESS))
    Yield;
  ACMainFileLstTraverse("~:/Compiler/*.HH*;*.HH*");
  LBtr(&ac.flags,ACf_INIT_IN_PROGRESS);
#endif
//Record executed command lines for AutoComplete's history view (SHIFT-F8).
  EnableHistory;
  OnceExe;
  if(FileFind("~/MakeHome.HC"))
    try ExeFile("~/MakeHome.HC");
    catch PutExcept;
  if(FileFind("~/HomeKeyPlugIns.HC"))
    ExeFile("~/HomeKeyPlugIns.HC");
//Last, so a demo or doc from the command line starts in a finished desktop.
  if(CmdLineBootFileCnt&&boot_user_task)
    CmdLineBootFilesToUser(boot_user_task);
}
CoreAPSethTask;
#endif;
