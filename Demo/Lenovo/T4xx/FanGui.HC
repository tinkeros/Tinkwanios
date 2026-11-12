#ifndef FAN_HC
U8 *fgui_inc_dir=DirCur;Cd(__DIR__);;
#include "Fan"
Cd(fgui_inc_dir);Free(fgui_inc_dir);;
#endif

#help_index "ACPI/FanGui"

#define FANSLD_WIDTH	56
#define FANSLD_GAP	20
#define FANSLD_TRAVEL	160
#define FANSLD_BORDER	2
#define FANSLD_TOP	(FONT_HEIGHT+6)
#define FANSLD_HEIGHT	(FANSLD_TOP+FANSLD_TRAVEL+2*FONT_HEIGHT+10)
#define FANLINK_HEIGHT	(FONT_HEIGHT+4)

#define FAN_GUI_ROW_Y	(3*FONT_HEIGHT)
#define FAN_GUI_BAR_W	120
#define FAN_GUI_BAR_H	(FONT_HEIGHT-2)
#define FAN_GUI_BAR_LO	20
#define FAN_GUI_BAR_HI	100

#define FAN_GUI_MODE_AUTO	0
#define FAN_GUI_MODE_MANUAL	1
#define FAN_GUI_MODE_FULL	2

#define FAN_GUI_CMD_AUTO	1
#define FAN_GUI_CMD_FULL	2
#define FAN_GUI_CMD_MANUAL	3

#define FAN_GUI_SAMPLE_MS	500

F64 fan_gui_level=0;
I64 fan_gui_mode=FAN_GUI_MODE_AUTO,
    fan_gui_applied=-1,
    fan_gui_rpm=0,
    fan_gui_status=0,
    fan_gui_max_temp=TP_THERM_NA;
I64 fan_gui_temps[TP_THERM_SENSORS];
Bool fan_gui_on=FALSE,
     fan_gui_ctrl_ok=FALSE,
     fan_gui_panic=FALSE;
CTask *fan_gui_sampler=NULL;

class CFanSliderState
{
  F64 *val;
  F64 vmin,vmax;
  U8 name[16];
};

U0 DrawCtrlFanSlider(CDC *dc,CCtrl *c)
{
  CFanSliderState *s=c->state;
  I64 knob_y,lvl,track_top=c->top+FANSLD_TOP;
  F64 frac;
  dc->color=LTBLUE;
  GrRect(dc,c->left,c->top,FANSLD_WIDTH,FANSLD_HEIGHT);
  dc->color=BLUE;
  GrRect(dc,c->left+FANSLD_BORDER,track_top,
	FANSLD_WIDTH-2*FANSLD_BORDER,FANSLD_TRAVEL);
  dc->color=WHITE;
  GrPrint(dc,c->left+(FANSLD_WIDTH-StrLen(s->name)*FONT_WIDTH)/2,
	c->top+3,"%s",s->name);
  frac=Clamp((*s->val-s->vmin)/(s->vmax-s->vmin),0.0,1.0);
  knob_y=track_top+FANSLD_TRAVEL-1-ToI64(frac*(FANSLD_TRAVEL-1));
  dc->color=BLACK;
  GrLine(dc,c->left+FANSLD_WIDTH/2,track_top,
	c->left+FANSLD_WIDTH/2,track_top+FANSLD_TRAVEL-1);
  if (fan_gui_ctrl_ok)
    dc->color=YELLOW;
  else
    dc->color=DKGRAY;
  GrRect(dc,c->left+4,knob_y-3,FANSLD_WIDTH-8,7);
  lvl=ToI64(*s->val+0.5);
  dc->color=WHITE;
  GrPrint(dc,c->left+(FANSLD_WIDTH-6*FONT_WIDTH)/2,
	track_top+FANSLD_TRAVEL+4,"lvl %d",lvl);
  GrPrint(dc,c->left+(FANSLD_WIDTH-8*FONT_WIDTH)/2,
	track_top+FANSLD_TRAVEL+4+FONT_HEIGHT,"%5d rpm",fan_gui_rpm);
}

U0 LeftClickFanSlider(CCtrl *c,I64,I64 y,Bool)
{//Dragging takes manual control.  No EC access here.
  CFanSliderState *s=c->state;
  F64 frac=1.0-ToF64(y-(c->top+FANSLD_TOP))/(FANSLD_TRAVEL-1);
  if (!fan_gui_ctrl_ok)
    return;
  *s->val=s->vmin+Clamp(frac,0.0,1.0)*(s->vmax-s->vmin);
  fan_gui_mode=FAN_GUI_MODE_MANUAL;
  fan_gui_panic=FALSE;
}

U0 UpdateDerivedCtrlFanSlider(CCtrl *c)
{
  CFanSliderState *s=c->state;
  *s->val=Clamp(*s->val,s->vmin,s->vmax);
}

CCtrl *FanSliderNew(I64 x,I64 y,F64 *val,F64 vmin,F64 vmax,U8 *name)
{
  CCtrl *c=CAlloc(sizeof(CCtrl));
  CFanSliderState *s=CAlloc(sizeof(CFanSliderState));
  s->val=val;
  s->vmin=vmin;
  s->vmax=vmax;
  StrCpy(s->name,name);
  c->win_task=Fs;
  c->flags=CTRLF_SHOW|CTRLF_CAPTURE_LEFT_MS;
  c->type=CTRLT_GENERIC;
  c->state=s;
  c->draw_it=&DrawCtrlFanSlider;
  c->left_click=&LeftClickFanSlider;
  c->update_derived_vals=&UpdateDerivedCtrlFanSlider;
  c->left=x;
  c->top=y;
  c->right=x+FANSLD_WIDTH-1;
  c->bottom=y+FANSLD_HEIGHT-1;
  QueIns(c,Fs->last_ctrl);
  TaskDerivedValsUpdate;
  return c;
}

U0 FanSliderDel(CCtrl *c)
{
  QueRem(c);
  Free(c->state);
  Free(c);
}

class CFanLinkState
{
  I64 cmd;
  U8 text[16];
};

U0 DrawCtrlFanLink(CDC *dc,CCtrl *c)
{
  CFanLinkState *s=c->state;
  if (fan_gui_ctrl_ok)
    dc->color=RED;
  else
    dc->color=DKGRAY;
  GrPrint(dc,c->left,c->top+2,"%s",s->text);
  GrLine(dc,c->left,c->top+2+FONT_HEIGHT,
	c->right,c->top+2+FONT_HEIGHT);
}

U0 LeftClickFanLink(CCtrl *c,I64,I64,Bool down)
{
  CFanLinkState *s=c->state;
  if (!down)
    PostMsg(c->win_task,MSG_CMD,s->cmd,0);
}

CCtrl *FanLinkNew(I64 x,I64 y,U8 *text,I64 cmd)
{
  CCtrl *c=CAlloc(sizeof(CCtrl));
  CFanLinkState *s=CAlloc(sizeof(CFanLinkState));
  s->cmd=cmd;
  StrCpy(s->text,text);
  c->win_task=Fs;
  c->flags=CTRLF_SHOW|CTRLF_CAPTURE_LEFT_MS;
  c->type=CTRLT_GENERIC;
  c->state=s;
  c->draw_it=&DrawCtrlFanLink;
  c->left_click=&LeftClickFanLink;
  c->left=x;
  c->top=y;
  c->right=x+StrLen(text)*FONT_WIDTH-1;
  c->bottom=y+FANLINK_HEIGHT-1;
  QueIns(c,Fs->last_ctrl);
  TaskDerivedValsUpdate;
  return c;
}

U0 FanLinkDel(CCtrl *c)
{
  QueRem(c);
  Free(c->state);
  Free(c);
}

U0 FanGuiApply()
{//Push the GUI's wishes at the hardware, if anything changed.
  I64 want;
  if (!fan_gui_ctrl_ok)
    return;
  if (fan_gui_mode==FAN_GUI_MODE_AUTO)
  {
    if (fan_gui_applied!=-1)
    {
      FanSetAuto;
      fan_gui_applied=-1;
    }
    return;
  }
  if (fan_gui_mode==FAN_GUI_MODE_FULL)
  {
    if (fan_gui_applied!=-2)
    {
      FanSetFullSpeed;
      fan_gui_applied=-2;
    }
    return;
  }
  want=ToI64(fan_gui_level+0.5);
  if (want<0)
    want=0;
  if (want>TP_FAN_LEVEL_MAX)
    want=TP_FAN_LEVEL_MAX;
  if (want!=fan_gui_applied)
  {
    FanSetLevel(want);
    fan_gui_applied=want;
  }
}

U0 FanGuiSampler(I64)
{//Read the hardware, apply the slider, panic if it gets hot.
  I64 i;
  while (fan_gui_on)
  {
    fan_gui_status=FanStatusRd();
    fan_gui_rpm=FanRpm();
    for (i=0;i<TP_THERM_SENSORS;i++)
      fan_gui_temps[i]=TempGet(i);
    fan_gui_max_temp=TempMax();

    if (fan_gui_max_temp!=TP_THERM_NA &&
	fan_gui_max_temp>=FAN_PANIC_TEMP &&
	fan_gui_mode!=FAN_GUI_MODE_AUTO)
    {
      fan_gui_mode=FAN_GUI_MODE_AUTO;
      fan_gui_panic=TRUE;
      FanSetAuto;
      fan_gui_applied=-1;
    }
    else if (fan_gui_max_temp==TP_THERM_NA &&
	     fan_gui_mode!=FAN_GUI_MODE_AUTO)
    {
      fan_gui_mode=FAN_GUI_MODE_AUTO;
      fan_gui_panic=TRUE;
      FanSetAuto;
      fan_gui_applied=-1;
    }
    else
      FanGuiApply;

    if (fan_gui_mode==FAN_GUI_MODE_AUTO && fan_gui_status>=0)
      fan_gui_level=ToF64(fan_gui_status & TP_FAN_LEVEL_MASK);

    Sleep(FAN_GUI_SAMPLE_MS);
  }
  fan_gui_sampler=NULL;
}

U8 *fan_gui_hdr_msg="Fan and thermals -- drag the fader; "
	"A auto, F full, ESC to close";
U8 *fan_gui_off_msg="Fan control disabled: set FAN_ALLOW_CONTROL to 1 in "
	"Demo/Lenovo/T4xx/Fan.HC (display only)";

I64 fan_gui_temps_x=0,fan_gui_temps_y=0;

U0 FanGuiTempBar(CDC *dc,I64 x,I64 y,I64 t)
{//A bar scaled FAN_GUI_BAR_LO..HI, coloured by how worried to be.
  I64 w;
  F64 frac;
  dc->color=DKGRAY;
  GrRect(dc,x,y,FAN_GUI_BAR_W,FAN_GUI_BAR_H);
  frac=Clamp(ToF64(t-FAN_GUI_BAR_LO)/(FAN_GUI_BAR_HI-FAN_GUI_BAR_LO),
	0.0,1.0);
  w=ToI64(frac*FAN_GUI_BAR_W);
  if (w<1)
    w=1;
  if (t>=FAN_PANIC_TEMP)
    dc->color=LTRED;
  else if (t>=70)
    dc->color=RED;
  else if (t>=55)
    dc->color=YELLOW;
  else
    dc->color=LTGREEN;
  GrRect(dc,x,y,w,FAN_GUI_BAR_H);
}

U0 FanGuiDrawBg(CTask *,CDC *dc)
{
  I64 i,y,t,n=0;
  I8 desc[64];
  dc->color=BLACK;
  GrPrint(dc,FANSLD_GAP,FONT_HEIGHT/2,"%s",fan_gui_hdr_msg);
  if (!fan_gui_ctrl_ok)
  {
    dc->color=RED;
    GrPrint(dc,FANSLD_GAP,FONT_HEIGHT/2+FONT_HEIGHT,"%s",fan_gui_off_msg);
  }

  FanStatusStr(fan_gui_status,desc);
  dc->color=BLACK;
  y=fan_gui_temps_y;
  if (fan_gui_mode==FAN_GUI_MODE_AUTO)
    GrPrint(dc,fan_gui_temps_x,y,"Mode: auto");
  else if (fan_gui_mode==FAN_GUI_MODE_FULL)
    GrPrint(dc,fan_gui_temps_x,y,"Mode: full speed");
  else
    GrPrint(dc,fan_gui_temps_x,y,"Mode: manual");
  y+=FONT_HEIGHT;
  GrPrint(dc,fan_gui_temps_x,y,"EC %02X: %02X  %s",
	TP_EC_FAN_STATUS,fan_gui_status,desc);
  y+=FONT_HEIGHT;
  GrPrint(dc,fan_gui_temps_x,y,"Tach : %d RPM",fan_gui_rpm);
  y+=FONT_HEIGHT;
  if (fan_gui_panic)
  {
    dc->color=LTRED;
    GrPrint(dc,fan_gui_temps_x,y,
	  "Backed off to auto, drag the fader to take over again");
    dc->color=BLACK;
  }
  y+=FONT_HEIGHT+FONT_HEIGHT/2;

  GrPrint(dc,fan_gui_temps_x,y,"Thermal sensors");
  y+=FONT_HEIGHT+2;
  for (i=0;i<TP_THERM_SENSORS;i++)
  {
    t=fan_gui_temps[i];
    if (t!=TP_THERM_NA)
    {
      dc->color=BLACK;
      GrPrint(dc,fan_gui_temps_x,y,"%2d %3d C",i,t);
      FanGuiTempBar(dc,fan_gui_temps_x+9*FONT_WIDTH,y,t);
      y+=FONT_HEIGHT+2;
      n++;
    }
  }
  dc->color=BLACK;
  if (!n)
    GrPrint(dc,fan_gui_temps_x,y,
	  "none readable -- check the offsets with ec_fan_probe.py");
  else if (fan_gui_max_temp!=TP_THERM_NA)
    GrPrint(dc,fan_gui_temps_x,y+2,"hottest %d C",fan_gui_max_temp);
}

U0 FanGuiFitWin(I64 need_w,I64 need_h)
{//Size the win to the contents, clamped to the screen.
  I64 cols=(need_w+FONT_WIDTH-1)/FONT_WIDTH,
      rows=(need_h+FONT_HEIGHT-1)/FONT_HEIGHT,
      left=Fs->win_left,top=Fs->win_top;
  if (cols>TEXT_COLS-2) cols=TEXT_COLS-2;
  if (rows>TEXT_ROWS-3) rows=TEXT_ROWS-3;
  if (left<1) left=1;
  if (left+cols-1>TEXT_COLS-2) left=TEXT_COLS-1-cols;
  if (top<2) top=2;
  if (top+rows-1>TEXT_ROWS-2) top=TEXT_ROWS-1-rows;
  WinHorz(left,left+cols-1);
  WinVert(top,top+rows-1);
}

public U0 FanTempGui()
{//Fan fader plus live temperatures.
  I64 arg1,arg2,i,link_y,need_w,need_h;
  CCtrl *slider,*link_auto,*link_full,*link_man;

  EcInit;
  if (FanStatusRd()<0)
  {
    "FanTempGui: the EC is not answering.\n"
    "Run FanRep first to see the ports it is using, and confirm the\n"
    "offsets with ec_fan_probe.py.\n";
    return;
  }

  fan_gui_ctrl_ok=FAN_ALLOW_CONTROL;
  fan_gui_mode=FAN_GUI_MODE_AUTO;
  fan_gui_applied=-1;
  fan_gui_panic=FALSE;
  fan_gui_status=FanStatusRd();
  fan_gui_rpm=FanRpm();
  for (i=0;i<TP_THERM_SENSORS;i++)
    fan_gui_temps[i]=TempGet(i);
  fan_gui_max_temp=TempMax();
  fan_gui_level=ToF64(fan_gui_status & TP_FAN_LEVEL_MASK);

  SettingsPush;
  MenuPush(
	"File {"
	"  Exit(,CH_ESC);"
	"}"
	"Fan {"
	"  Auto(,'a');"
	"  Full(,'f');"
	"}"
	);
  DocClear;
  Fs->draw_it=&FanGuiDrawBg;

  link_y=FAN_GUI_ROW_Y+FANSLD_HEIGHT+4;
  slider=FanSliderNew(FANSLD_GAP,FAN_GUI_ROW_Y,&fan_gui_level,
	0.0,ToF64(TP_FAN_LEVEL_MAX),"Fan");
  link_auto=FanLinkNew(FANSLD_GAP+(FANSLD_WIDTH-4*FONT_WIDTH)/2,
	link_y,"Auto",FAN_GUI_CMD_AUTO);
  link_full=FanLinkNew(FANSLD_GAP+(FANSLD_WIDTH-4*FONT_WIDTH)/2,
	link_y+FANLINK_HEIGHT+2,"Full",FAN_GUI_CMD_FULL);
  link_man=FanLinkNew(FANSLD_GAP+(FANSLD_WIDTH-6*FONT_WIDTH)/2,
	link_y+2*(FANLINK_HEIGHT+2),"Manual",FAN_GUI_CMD_MANUAL);

  fan_gui_temps_x=FANSLD_GAP+FANSLD_WIDTH+2*FANSLD_GAP;
  fan_gui_temps_y=FAN_GUI_ROW_Y;

  need_w=fan_gui_temps_x+9*FONT_WIDTH+FAN_GUI_BAR_W+FANSLD_GAP;
  i=FANSLD_GAP+StrLen(fan_gui_hdr_msg)*FONT_WIDTH+2*FANSLD_BORDER;
  if (i>need_w) need_w=i;
  if (!fan_gui_ctrl_ok)
  {
    i=FANSLD_GAP+StrLen(fan_gui_off_msg)*FONT_WIDTH+2*FANSLD_BORDER;
    if (i>need_w) need_w=i;
  }
  need_h=link_y+3*(FANLINK_HEIGHT+2)+FONT_HEIGHT;
  i=fan_gui_temps_y+(TP_THERM_SENSORS+8)*(FONT_HEIGHT+2);
  if (i>need_h) need_h=i;
  FanGuiFitWin(need_w,need_h);

  fan_gui_on=TRUE;
  fan_gui_sampler=Spawn(&FanGuiSampler,NULL,"FanSample",,Fs);

  try {
    while (TRUE) {
      switch (GetMsg(&arg1,&arg2,1<<MSG_KEY_DOWN|1<<MSG_CMD)) {
	case MSG_KEY_DOWN:
	  switch (arg1) {
	    case 'a':
	    case 'A':
	      fan_gui_mode=FAN_GUI_MODE_AUTO;
	      fan_gui_panic=FALSE;
	      break;
	    case 'f':
	    case 'F':
	      if (fan_gui_ctrl_ok)
	      {
		fan_gui_mode=FAN_GUI_MODE_FULL;
		fan_gui_panic=FALSE;
	      }
	      break;
	    case CH_ESC:
	    case CH_SHIFT_ESC:
	      throw;
	  }
	  break;
	case MSG_CMD:
	  if (arg1==FAN_GUI_CMD_AUTO)
	  {
	    fan_gui_mode=FAN_GUI_MODE_AUTO;
	    fan_gui_panic=FALSE;
	  }
	  else if (arg1==FAN_GUI_CMD_FULL && fan_gui_ctrl_ok)
	  {
	    fan_gui_mode=FAN_GUI_MODE_FULL;
	    fan_gui_panic=FALSE;
	  }
	  else if (arg1==FAN_GUI_CMD_MANUAL && fan_gui_ctrl_ok)
	  {
	    fan_gui_mode=FAN_GUI_MODE_MANUAL;
	    fan_gui_panic=FALSE;
	  }
	  break;
      }
      Refresh;
    }
  } catch
    Fs->catch_except=TRUE;

  fan_gui_mode=FAN_GUI_MODE_AUTO;
  if (fan_gui_ctrl_ok)
    FanSetAuto;
  fan_gui_on=FALSE;
  while (TaskValidate(fan_gui_sampler))
    Sleep(FAN_GUI_SAMPLE_MS/2);
  fan_gui_sampler=NULL;

  FanSliderDel(slider);
  FanLinkDel(link_auto);
  FanLinkDel(link_full);
  FanLinkDel(link_man);
  Fs->draw_it=NULL;
  MenuPop;
  SettingsPop;
}

#ifndef FAN_GUI_NO_AUTORUN
try {
  FanTempGui;
}
catch {
  Fs->catch_except=TRUE;
}
Exit;
#endif

#help_index ""
