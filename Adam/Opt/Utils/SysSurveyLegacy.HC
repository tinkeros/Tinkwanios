//The original long-form system survey, shipped in the Sup1 supplemental
//ISO and #included with #include,opt so the base distro builds without it.
//$LK,"SysSurvey",A="MN:SysSurvey"$() is the short one. Uses
//$LK,"YNorU",A="MN:YNorU"$() from SysSurvey.HC, so that must be
//#included first.

I64 AskQuestion(U8 *q)
{
  I64 def=q[StrLen(q)+1];
  "%s ",q;
  return YNorU(def);
}

#define NUM_INS_SURVEY_QUESTIONS 3

static U8 *ins_questions[NUM_INS_SURVEY_QUESTIONS]=
{
  "Did the automatic installer work\0u",
  "Did you manually partition and format the drive\0u",
  "Did you manually have to enter IO port numbers\0u",
};

#define NUM_STD_SURVEY_QUESTIONS 10

static U8 *std_questions[NUM_STD_SURVEY_QUESTIONS]=
{
  "Is AHCI mode supported in BIOS\0u",
  "Is Legacy/IDE mode supported in BIOS\0u",
  "Does PS/2 emulation of USB both keyboard and mouse work in TinkerOS\0u",
  "Does your system have a PS/2 mouse or combo port\0u",
  "Does your system have a serial port\0u",
  "Does your system have a parallel port\0u",
  "Can you install and run TinkerOS bare metal\0u",
  "Can you install and run TempleOS bare metal\0u",
  "Does PS/2 emulation of USB both keyboard and mouse work in TempleOS\0u",
  "Is this a custom built PC / motherboard you installed\0u",
};


#define NUM_USB_SURVEY_QUESTIONS 2

static U8 *usb_questions[NUM_USB_SURVEY_QUESTIONS]=
{
  "Does the USB keyboard work in TinkerOS (native USB driver)\0u",
  "Does the USB mouse work in TinkerOS (native USB driver)\0u",
};

#define SURVEY_STD_PS2_TOS	2
#define SURVEY_STD_PS2_TEMPLE	8

U0 SetDefaultResp(U8 *q, I64 resp)
{
  q[StrLen(q)+1]=resp;
}

Bool SurveyUsbBoot()
{//TRUE if the boot drive is a USB stick (TinkerOS's own USB driver).
  CDrv *dv;
  I64 let=blkdev.boot_drv_let;
  if (!DrvMounted(let)) return FALSE;
  dv=Let2Drv(let);
  if (!dv || !dv->bd) return FALSE;
  return dv->bd->type==BDT_USB;
}

I64 SurveyUsbCnt(I64 kind,I64 kind2=-1)
{//How many USB devices of kind (or kind2) are plugged in.
  I64 k,n=0,t;
  for (k=0; k<16; k++)
  {
    t=UsbDevKind(k);
    if (t>0 && (t==kind || t==kind2))
      n++;
  }
  return n;
}


public U0 RunSysSurveyLegacy()
{
  CDrv *dv;
  U8 *notes=NULL, *survey_file;
  Bool is_laptop,installed=FALSE,sysrep,clonezilla,usb_boot,ask_usb,skip_ps2;
  I64 have_kbd_ms,have_expresscard,have_dock,i,resp[NUM_STD_SURVEY_QUESTIONS],
      resp_ins[NUM_INS_SURVEY_QUESTIONS],resp_usb[NUM_USB_SURVEY_QUESTIONS],
      usb_kbd,usb_ms;

  DocClear;
  WinMax;
  DocMax;
  AutoComplete(0);

  if (blkdev.boot_drv_let != 'B' && blkdev.boot_drv_let !='T') installed=TRUE;

  usb_boot=SurveyUsbBoot;
  usb_kbd=SurveyUsbCnt(USB_KIND_KBD);
  usb_ms=SurveyUsbCnt(USB_KIND_MOUSE,USB_KIND_TABLET);
  ask_usb=usb_boot || usb_kbd || usb_ms;
  skip_ps2=usb_boot && usb_kbd && usb_ms;
  if (usb_kbd) SetDefaultResp(usb_questions[0],'y');
  else SetDefaultResp(usb_questions[0],'u');
  if (usb_ms) SetDefaultResp(usb_questions[1],'y');
  else SetDefaultResp(usb_questions[1],'u');

  if (AHCIMode) SetDefaultResp(std_questions[0],'y');
  else SetDefaultResp(std_questions[0],'n');

  if (!AHCIMode) SetDefaultResp(std_questions[1],'y');

  DefineLstLoad("ST_SYS_SURVEY","No\0Yes\0Unknown\0NA\0");
  if (ask_usb)
  {
    if (usb_boot)
      "Booted from USB. ";
    "USB keyboards found: %d, USB mice/pointers found: %d\n\n",usb_kbd,usb_ms;
    for (i=0; i<NUM_USB_SURVEY_QUESTIONS; i++)
    {
      resp_usb[i]=AskQuestion(usb_questions[i]);
      "\n";
    }
  }

  for (i=0; i<NUM_STD_SURVEY_QUESTIONS; i++)
  {
    if (skip_ps2 && (i==SURVEY_STD_PS2_TOS || i==SURVEY_STD_PS2_TEMPLE))
      resp[i]=3;
    else
    {
      resp[i]=AskQuestion(std_questions[i]);
      if ((i==1||i==6) && resp[i]==0)
      {
        SetDefaultResp(std_questions[7],'n');
        SetDefaultResp(std_questions[8],'n');
      }
      if (i==2 && resp[i]==0)
        SetDefaultResp(std_questions[8],'n');
      "\n";
    }
  }

  "Is your system a laptop ";
  is_laptop=YorN('n');
  "\n";

  if (is_laptop)
  {
    "Do the laptop keyboard and trackpad both work ";
    have_kbd_ms=YNorU('u');
    "\n";
    "Do you have a dock with useful ports (ps/2,serial,parallel) ";
    have_dock=YNorU('u');
    "\n";
    "Does your laptop have an expresscard slot ";
    have_expresscard=YNorU('u');
    "\n";
  }

  if (installed && !usb_boot)
  {
    for (i=0; i<NUM_INS_SURVEY_QUESTIONS; i++)
    {
      resp_ins[i]=AskQuestion(ins_questions[i]);
      "\n";
    }
  }

  "\n";
  "You are able to automatically include important useful\n";
  "information on your hardware (serial numbers and other\n";
  "identifying personal information is excluded) and you\n";
  "can always review and delete anything from the output\n";
  "before sending it.\n\n";

  "Can I gather this hardware information to include ";

  sysrep=YorN('y');

  "\n";
  "Any extra notes you would like to share ";

  if (YorN('n'))
  {
    notes=PopUpGetStr("Please enter extra notes, then press ESC\n");
  }

  DocClear;

  "Survey and System Results:\n\n";

#ifdef SCREEN_SAVER_TIMEOUT
  "OS: TinkerOS V%5.3f\t%D %T\n\n",sys_os_version,sys_compile_time,sys_compile_time;
#else
  "OS: TempleOS V%5.3f\t%D %T\n\n",sys_os_version,sys_compile_time,sys_compile_time;
#endif

  "Current graphics mode: %d x %d (%d by %d framebuffer)\n\n",
    GR_WIDTH,GR_HEIGHT,FB_WIDTH,FB_HEIGHT;
  "Current disk mode: ";
  if (AHCIMode) "AHCI\n\n";
  else "IDE/Legacy\n\n";
  "Current boot drive: %C\n\n",blkdev.boot_drv_let;
  "Booted from USB: %s\n\n",DefineSub(usb_boot,"ST_SYS_SURVEY");
  "USB keyboards: %d, USB mice/pointers: %d\n\n",usb_kbd,usb_ms;
  if (ask_usb)
    for (i=0; i<NUM_USB_SURVEY_QUESTIONS; i++)
      "%s: %s\n\n",usb_questions[i],DefineSub(resp_usb[i],"ST_SYS_SURVEY");


  "Laptop: %s\n\n",DefineSub(is_laptop,"ST_SYS_SURVEY");
  if (is_laptop)
    "Dock with useful ports available: %s\n\n",DefineSub(have_dock,"ST_SYS_SURVEY");
  if (is_laptop)
    "Expresscard slot available: %s\n\n",DefineSub(have_expresscard,"ST_SYS_SURVEY");
  if (is_laptop)
    "Do laptop keyboard and trackpad both work: %s\n\n",DefineSub(have_kbd_ms,"ST_SYS_SURVEY");

  for (i=0; i<NUM_STD_SURVEY_QUESTIONS; i++)
  {
    "%s: %s\n\n",std_questions[i],DefineSub(resp[i],"ST_SYS_SURVEY");
  }

  if (installed && !usb_boot)
  {
    for (i=0; i<NUM_INS_SURVEY_QUESTIONS; i++)
    {
      "%s: %s\n\n",ins_questions[i],DefineSub(resp_ins[i],"ST_SYS_SURVEY");
    }
  }

  if (!AHCIMode)
    GetBootDrvPortInfo;

  if (notes) "Extra notes: \n\n%s\n\n",notes;

  "USB devices:\n";
  UsbRep;
  "\n";

  if (sysrep)
  {
    "Results from SysRepSurvey:\n\n";
    SysRepSurvey;
  }


  "\nHypervisor present: %d\n\n",IsHypervisorPresent;

  VidModes;
  "\n";

  if (DrvMounted('C')||DrvMounted('D')||DrvMounted('E')||DrvMounted('F'))
  {
    clonezilla=TRUE;
    for (i=0;i<4;i++)
    {
      if (DrvMounted('C'+i))
      {
        dv=Let2BlkDev('C'+i);
        if (!dv || dv->size != 0x256534442) clonezilla=FALSE;
      }
    }
  }
  else clonezilla=FALSE;

  if (clonezilla) "It appears clonezilla was used to partition the drive.\n";

  if (installed && blkdev.boot_drv_let != 'T')
    survey_file=MStrPrint("%C:/Home/Survey.DD",blkdev.boot_drv_let);
  else
  {
    DirMk("B:/Home");
    survey_file=MStrPrint("B:/Home/Survey.DD");
  }

  StrCpy(Fs->put_doc->filename.name,survey_file);
  DocWrite(Fs->put_doc);

  "\nWrote %s, please transfer to an internet connected PC\n",survey_file;
  "and rename it appropriately and make a github pull\n";
  "request to add your system! This will help others\n";
  "know what systems are TOS compatible!\n\n";

  if (SNAIL_COM>0)
  {
    "Attempt to automatically send survey to TOS server over serial port ";
    if (YorN('y'))
      Fput(survey_file,"Survey.DD");
  }

  Free(survey_file);
  Free(notes);
  AutoComplete(1);
}

#help_index "SysInfo"
public U0 SysSurveyLegacy()
{//Run the long original system survey
  User("RunSysSurveyLegacy;\n");
}
#help_index ""
