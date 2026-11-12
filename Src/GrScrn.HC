#help_index "Graphics/Scrn"

U0 GrUpdateTaskODEs(CTask *task)
{
  sys_task_being_scrn_updated=task;
  try
    ODEsUpdate(task);
  catch {
    LBts(&task->win_inhibit,WIf_SELF_ODE);
    "Exception in WinMgr: Update Task ODEs\n";
    PutExcept;
    Sleep(3000);
    //VGAFlush;
  }
  sys_task_being_scrn_updated=NULL;
}

U0 GrUpdateTaskWin(CTask *task)
{ //Draw a win.  Only Core0 tasks have a win.
  CDC *dc;
  CD3I64 saved_scroll;
  sys_task_being_scrn_updated=task;
  try {
    if (!Bt(&task->display_flags,DISPLAYf_NO_BORDER)) {
      TextBorder(Fs,task->win_left,task->win_right,task->win_top,
	    task->win_bottom,task->border_attr,task==sys_focus_task);
    }
    TextRect(task->win_left,task->win_right,
	  task->win_top,task->win_bottom,task->text_attr<<8);
    if (task==sys_winmgr_task) {
      if (gr.fp_wall_paper) {
	(*gr.fp_wall_paper)(task);
	}
    } else if (!(task->win_inhibit&WIF_SELF_DOC))
      DocUpdateTaskDocs(task);
    if (TaskValidate(task)) {
      if (task->draw_it) {
	dc=DCAlias(gr.dc2,task);
	(*task->draw_it)(task,dc);
	DCDel(dc);
      }
      if (TaskValidate(task)) {
	WinScrollNull(task,&saved_scroll);
	DrawCtrls(task);
	WinScrollRestore(task,&saved_scroll);
      }
    }
  } catch {
    if (task!=Fs && TaskValidate(task)) {
      LBtr(&task->display_flags,DISPLAYf_SHOW);
      "Exception in WinMgr: Update Task Win\n";
      PutExcept;
      Sleep(3000);
    }
  }
  sys_task_being_scrn_updated=NULL;
}

U0 GrUpdateTasks()
{//Only called by WinMgr
  I64 i;
  CTask *task,*task1;
  try {
    winmgr.ode_time=0;
    if (Bt(&sys_semas[SEMA_UPDATE_WIN_Z_BUF],0))
      WinZBufUpdate;
    task1=task=sys_winmgr_task;
    do { //Loop through Core0 tasks.
      if (!TaskValidate(task)) break;
      if (Bt(&task->display_flags,DISPLAYf_SHOW) &&
	    Bt(gr.win_uncovered_bitmap,task->win_z_num))
	GrUpdateTaskWin(task);
      if (!TaskValidate(task)) 
        break;
      task=task->next_task;
    } while (task!=task1);

    for (i=0;i<mp_cnt;i++) { //Loop through all cores.
      task1=task=cpu_structs[i].seth_task;
      do {
	if (!TaskValidate(task)) break;
	GrUpdateTaskODEs(task);
	if (!TaskValidate(task)) break;
	task=task->next_task;
      } while (task!=task1);
    }
  } catch {
    PutExcept(TRUE);
    //Dbg("Exception in WinMgr"); TODO RESTORE
  }
  winmgr.last_ode_time=winmgr.ode_time;
  ode_alloced_factor=LowPass1(0.1,ode_alloced_factor,
    Clamp(Gs->idle_factor-0.1,0.2,0.8),1/winmgr.fps);
  sys_task_being_scrn_updated=NULL;
}

U0 GrFixZoomScale()
{
  gr.scrn_zoom=ClampI64(gr.scrn_zoom,1,GR_SCRN_ZOOM_MAX);
  if (gr.scrn_zoom==1) {
    gr.sx=0;
    gr.sy=0;
  } else {
    gr.sx=ClampI64(gr.sx,0,GR_WIDTH-GR_WIDTH/gr.scrn_zoom)&~7;
    gr.sy=ClampI64(gr.sy,0,GR_HEIGHT-GR_HEIGHT/gr.scrn_zoom);
  }
}

public U0 GrScaleZoom(F64 scale)
{//Multiply zoom factor larger or smaller.
  F64 s=gr.scrn_zoom;
  gr.scrn_zoom=gr.scrn_zoom*scale;
  GrFixZoomScale;
  s/=gr.scrn_zoom;
  ms.scale.x*=s;
  ms.scale.y*=s;
  ms.scale.z*=s;
  ms.offset.x=ms.pos.x-(ms.pos.x-ms.offset.x)*s;
  ms.offset.y=ms.pos.y-(ms.pos.y-ms.offset.y)*s;
  ms.offset.z=ms.pos.z-(ms.pos.z-ms.offset.z)*s;
  gr.sx=ms.pos.x-gr.zoomed_dc->width >>1/gr.scrn_zoom;
  gr.sy=ms.pos.y-gr.zoomed_dc->height>>1/gr.scrn_zoom;
  GrFixZoomScale;
}

U0 GrZoomInScrn()
{
  GrFixZoomScale;
  I64 k,l,span,j,y;
  U8 *src,*src_cap,*dst,*ndst;
  dst=gr.zoomed_dc->body;
  span=gr.zoomed_dc->width/gr.scrn_zoom;
  for(y=0;y!=gr.zoomed_dc->height/gr.scrn_zoom;y++) {
    src=gr.dc2->body+gr.sx+(gr.sy+y)*gr.dc2->width_internal;  
    src_cap=src+span;
//We fill 1 row then we multiply that row,gr.scrn_zoom times
    //This will make our "pixels" sqaure
    while(src!=src_cap) {
      for(k=0;k!=gr.scrn_zoom;k++)
        *dst++=*src;
      src++;
    }
    dst-=span*gr.scrn_zoom;
    //Repeat the zoomed rows as they are the same
    for(l=1;l<gr.scrn_zoom;l++) {
      ndst=dst+gr.zoomed_dc->width_internal;
      MemCpy(ndst,dst,gr.zoomed_dc->width_internal);
      dst=ndst;
    }
    dst=ndst+gr.zoomed_dc->width_internal;
  }
}

U0 GrUpdateTextBG()
{
  I64 *dst=gr.dc2->body, c,row,col,
	num_rows=TEXT_ROWS,num_cols=TEXT_COLS,i,j,cur_ch,
  w1=gr.dc2->width_internal,w2=-7*w1+8,w3=7*w1,w4=0;
  U32 *src=gr.text_base;
  Bool blink_flag=Blink(2.5);
  U8 *dst2=dst,*dst3;

  if (gr.pan_text_x||gr.hide_col) {
    gr.pan_text_x=ClampI64(gr.pan_text_x,-7,7);
    j=AbsI64(gr.pan_text_x)/FONT_WIDTH+1;
    num_cols-=j;
    if (gr.pan_text_x<0) {
      src+=j;
      i=FONT_WIDTH*j+gr.pan_text_x;
    } else
      i=gr.pan_text_x;
    dst2=dst(U8 *)+i;
    w4=j;
    w3+=j*FONT_WIDTH;

    j*=FONT_WIDTH;
    dst(U8 *)=gr.dc2->body;
    for (row=num_rows*FONT_HEIGHT;row--;) {
      for (col=i;col--;)
	*dst(U8 *)++=0;
      dst(U8 *)+=w1-i-j;
      for (col=j;col--;)
	*dst(U8 *)++=0;
    }
  }
  dst=dst2;

  if (gr.pan_text_y||gr.hide_row) {
    gr.pan_text_y=ClampI64(gr.pan_text_y,-7,7);
    j=AbsI64(gr.pan_text_y)/FONT_HEIGHT+1;
    num_rows-=j;
    if (gr.pan_text_y<0) {
      src+=w1/FONT_WIDTH*j;
      i=w1*(FONT_HEIGHT*j+gr.pan_text_y);
    } else
      i=w1*gr.pan_text_y;
    dst2=dst(U8 *)+i;

    j*=w1*FONT_HEIGHT;
    dst(U8 *)=gr.dc2->body;
    for (row=i;row--;)
      *dst(U8 *)++=0;
    dst(U8 *)=gr.dc2->body+TEXT_ROWS*TEXT_COLS*FONT_HEIGHT*FONT_WIDTH-j;
    for (row=j;row--;)
      *dst(U8 *)++=0;
  }
  dst=dst2;

  for (row=num_rows;row--;) {
    for (col=num_cols;col--;) {
      cur_ch=*src++;
      if (cur_ch & (ATTRF_SEL|ATTRF_INVERT|ATTRF_BLINK)) {
	if (cur_ch & ATTRF_SEL)
	  cur_ch.u8[1]=cur_ch.u8[1]^0xFF;
	if (cur_ch & ATTRF_INVERT)
	  cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
	if (cur_ch & ATTRF_BLINK && blink_flag)
	  cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
      }
      c=gr.to_8_colors[cur_ch.u8[1]>>4];
      *dst=c;
      dst(U8*)+=w1;
      *dst=c;
      dst(U8*)+=w1;
      *dst=c;
      dst(U8*)+=w1;
      *dst=c;
      dst(U8*)+=w1;
      *dst=c;
      dst(U8*)+=w1;
      *dst=c;
      dst(U8*)+=w1;
      *dst=c;
      dst(U8*)+=w1;
      *dst=c;
      dst(U8 *)+=w2;
    }
    src+=w4;
    dst(U8 *)+=w3;
  }
}

U0 GrUpdateTextFG()
{//See $LK,"TextBase Layer",A="HI:TextBase Layer"$.
  U32 *src=gr.text_base;
  I64 i,j,cur_ch,*dst=gr.dc2->body,
	w1=gr.dc2->width_internal,w2=7*w1,w4=0,
	num_rows=TEXT_ROWS,num_cols=TEXT_COLS,row,col;
  U8 *dst_start=gr.dc2->body,*dst_end=dst_start+w1*gr.dc2->height-7*w1-8;
  Bool blink_flag=Blink(2.5);

  if (gr.pan_text_x||gr.hide_col) {
    gr.pan_text_x=ClampI64(gr.pan_text_x,-7,7);
    j=AbsI64(gr.pan_text_x)/FONT_WIDTH+1;
    num_cols-=j;
    if (gr.pan_text_x<0) {
      src+=j;
      dst(U8 *)+=FONT_WIDTH*j;
    }
    w4=j;
    w2+=j*FONT_WIDTH;
  }

  if (gr.pan_text_y||gr.hide_row) {
    gr.pan_text_y=ClampI64(gr.pan_text_y,-7,7);
    j=AbsI64(gr.pan_text_y)/FONT_HEIGHT+1;
    num_rows-=j;
    if (gr.pan_text_y<0) {
      src+=w1/FONT_WIDTH*j;
      dst(U8 *)+=w1*FONT_HEIGHT*j;
    }
  }

  for (row=num_rows;row--;) {
    for (col=num_cols;col--;) {
      cur_ch=*src++;
      if (cur_ch & (ATTRF_UNDERLINE|ATTRF_SEL|ATTRF_INVERT|ATTRF_BLINK)) {
	if (cur_ch & ATTRF_SEL)
	  cur_ch.u8[1]=cur_ch.u8[1]^0xFF;
	if (cur_ch & ATTRF_INVERT)
	  cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
	if (cur_ch & ATTRF_BLINK && blink_flag)
	  cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
      }
      if (i=cur_ch.u16[1]&0x3FF+gr.pan_text_x+gr.pan_text_y<<5) {
	j=i&0x1F;
	if (j&0x10) j|=~0x1F;
	i>>=5;
	if (i&0x10) i|=~0x1F;
	i=w1*i+j;
	if (dst_start<=dst(U8 *)+i<dst_end)
	  GrRopEquU8NoClipping(cur_ch&(ATTRF_UNDERLINE+0xFFF),dst(U8 *)+i,w1);
      } else
	GrRopEquU8NoClipping(cur_ch&(ATTRF_UNDERLINE+0xFFF),dst,w1);
      dst(U8 *)+=8;
    }
    src+=w4;
    dst(U8 *)+=w2;
  }
}

U0 DCBlotColor8(CDC *dc,CDC *img)
{//Composite img over dc, 8 pixels at a time. A src pixel of TRANSPARENT
 //(0xFF) leaves the dst pixel alone, anything else overwrites it.
 //
 //This used to read a pixel's high nibble as the transparency flag and mask
 //the result down with 0x0f0f..., i.e. it silently truncated every color to
 //4 bits -- which is what kept the OS at 16 colors even though the screen
 //surface is 8 bits per pixel. The test is now against the whole byte, so
 //the extended palette (see Src/PalGen.HC) survives compositing.
  U64 *src=img->body,*b0=dc->body;
  U64 j,k,d0=img->width_internal*img->height/8;
  U64 v,h,mask;
  for (k=0;k<d0;k++) {
    j=*src++;
    //0x00 in every byte that was TRANSPARENT...
    v=j^0xFFFFFFFFFFFFFFFF;
    //...which the classic zero-byte test turns into 0x80 there and 0 elsewhere.
    h=(v-0x0101010101010101)&~v&0x8080808080808080;
    //0x80 -> 0xFF per byte: 0x80|(0x80-0x01), and 0 stays 0.
    mask=h|(h-(h>>7));
    //Keep the dst where src was transparent, take the src everywhere else.
    //A dst that is itself TRANSPARENT stays that way, as before.
    *b0=(j&~mask)|(*b0&mask);
    b0++;
  }
}

U8 term_colors[16]={
   BLACK,RED,GREEN,BROWN,BLUE,PURPLE,CYAN,DKGRAY,
   LTGRAY,LTRED,LTGREEN,YELLOW,LTBLUE,LTPURPLE,LTCYAN,WHITE
};
U0 DynPrint(U8 **buf,U8 **final,U8 *fmt,...) {
  fmt=StrPrintJoin(NULL,fmt,argc,argv);;
  OutStr(fmt,final,buf,0,0);
  Free(fmt);
}
U0 GrUpdateTextModeText()
{
//Write all at once to avoid buffering
  U8 *dump=NULL;
  U32 *src=gr.text_base;
  U8 *final=dump;
  I64 cur_ch,i=TEXT_COLS*TEXT_ROWS;
  I64 across=0,line=1;
  Bool blink_flag=Blink(2.5),underline=FALSE,ounderline=FALSE;
  U8 fg,bg,ofg=BLACK,obg=BLACK;
  I64 want;
#define ANSI_CSI "\x1b["
  DynPrint(&dump,&final,
	ANSI_CSI"0m" //Default
	ANSI_CSI"1;1H" //1,1 position
	ANSI_CSI"30m" //FG BLACK
	ANSI_CSI"38m" //BG BLACK
	ANSI_CSI"?25l" //Hide Cursor
	);
  while (i--) {
    cur_ch=*src++;
    if (cur_ch & ATTRF_SEL)
      cur_ch.u8[1]=cur_ch.u8[1]^0xFF;
    if (cur_ch & ATTRF_INVERT)
      cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
    if (cur_ch & ATTRF_BLINK)
      if (blink_flag)
        cur_ch.u8[1]=cur_ch.u8[1]<<4+cur_ch.u8[1]>>4;
    if (cur_ch & ATTRF_UNDERLINE)
      underline=TRUE;
    else
      underline=FALSE;
    fg=cur_ch.u8[1]&0xf;
    bg=cur_ch.u8[1]>>4;
    if(fg!=ofg) {
      want=0;
      while(term_colors[want]!=fg&&want<=15)
        want++;
      if(want>=8)
        DynPrint(&dump,&final,ANSI_CSI"9%dm",want-8);
      else
        DynPrint(&dump,&final,ANSI_CSI"3%dm",want);
      ofg=fg;
    }
    if(bg!=obg) {
      want=0;
      while(term_colors[want]!=bg&&want<=15)
        want++;
      if(want>=8)
        DynPrint(&dump,&final,ANSI_CSI"10%dm",want-8);
      else
        DynPrint(&dump,&final,ANSI_CSI"4%dm",want);
      obg=bg;
    }
    if(underline!=ounderline) {
      if(underline)
        DynPrint(&dump,&final,ANSI_CSI"4m");
      else
        DynPrint(&dump,&final,ANSI_CSI"24m");
      ounderline=underline;
    }
    if(32<=cur_ch.u8[0]<=126)
      DynPrint(&dump,&final,"%c",cur_ch.u8[0]);
    else
      DynPrint(&dump,&final," ");
    if(++across==TEXT_COLS) {
      DynPrint(&dump,&final,ANSI_CSI"%d;1H",++line);
      across=0;
    }
  }
  DynPrint(&dump,&final,
	ANSI_CSI"?25h" //Enable Cursor
  );
//Write all at once to avoid flicker
  DbgPutS(final);
  Free(final);
}


#help_index "ScreenSaver"
public U0 SetScreenSaverTimeout(I64 new_timeout)
{//Set timeout value for screen saver in seconds
  if (new_timeout<1)
    gr.scrn_saver_timeout=0;
  else
    gr.scrn_saver_timeout=new_timeout;
}

#help_index "Video"
public I64 GetFPS()
{//Return current target video FPS
  return fps_master;
}

#help_index "ScreenSaver"
U0 ScreenSaverDefault(CDC *dc,I64 ss_cnts)
{//Built-in default. Replaced by AdamFile("/Demo/ScreenSavers/<x>.HC").
  I64 rand_x,rand_y;
  if (fps_master && !(ss_cnts%fps_master)) {
    rand_x=RandRange(,GR_WIDTH-100);
    rand_y=RandRange(,GR_HEIGHT-FONT_HEIGHT);
    DCClear(dc);
    dc->color=WHITE;
    GrPrint(dc,rand_x,rand_y,"Screen Saver");
  }
}

static I64 ss_wait_ticks=0;
static CBGR24 ss_saved_palette[PAL_COLORS_NUM];

Bool GrScreenSaverUpdate()
{//TRUE when the screen saver owns the screen; gr.ss then holds the frame.
//KbdMsEvtTime is in jiffies here, not TSC.
  if (gr.scrn_saver_timeout &&
      (cnts.jiffies-KbdMsEvtTime)/JIFFY_FREQ>gr.scrn_saver_timeout)
    ss_wait_ticks++;
  else
    ss_wait_ticks=0;
  if (ss_wait_ticks>5) {
    if (!gr.scrn_saver) {
      VGAFlush;
      gr.scrn_zoom=1;
      gr.scrn_saver=TRUE;
      gr.scrn_saver_cnts=0;
      if (TaskValidate(gr.scrn_saver_task))
	Kill(gr.scrn_saver_task);
      gr.scrn_saver_task=NULL;
      //Save the palette and give the screen saver the default one.
      ClassCpy(ss_saved_palette,gr_palette,PAL_COLORS_NUM);
      GrSetExtPalette;
    } else {
      if (gr.scrn_saver_cnts<5)
	VGAFlush;
      gr.scrn_saver_cnts++;
    }
    if (gr.fp_draw_ss)
      (*gr.fp_draw_ss)(gr.ss,gr.scrn_saver_cnts);
    return TRUE;
  }
  if (gr.scrn_saver) {
    VGAFlush;
    gr.scrn_zoom=1;
    gr.scrn_saver=FALSE;
    gr.scrn_saver_cnts=0;
    if (TaskValidate(gr.scrn_saver_task))
      Kill(gr.scrn_saver_task);
    gr.scrn_saver_task=NULL;
    //Restore the palette in case the screen saver changed it.
    ClassCpy(gr_palette,ss_saved_palette,PAL_COLORS_NUM);
  }
  return FALSE;
}
#help_index ""

Bool GrUpdateScrn()
{//Called by the Window Manager $LK,"HERE",A="FF:::/Adam/WinMgr.HC,GrUpdateScrn"$, 30 times a second.
  CDC *dc;
  I64 oldc=TEXT_COLS,oldr=TEXT_ROWS;
//Suspended means suspended: a task that has taken over text.fb_alias must
//not get anything drawn over it.
  if(Bt(&Fs->task_flags,TASKf_SUSPENDED)) return FALSE;
  //Finish rendering previous frame
  if(ScreenUpdateInProgress) return FALSE;
  if(IsCmdLineMode2) {
    TermSize(&text.cols,&text.rows);
    if(oldc!=TEXT_COLS||oldr!=TEXT_ROWS)
      GrSetTextBaseSize(TEXT_COLS,TEXT_ROWS);
  }
  if (0) //if text mode
    ;//GrUpdateTasks; TODO RESTORE
  else {
    GrUpdateTextBG;
    GrUpdateTextFG;
    GrUpdateTasks;
    DCBlotColor8(gr.dc2,gr.dc);
  }

  dc=DCAlias(gr.dc2,Fs);
  dc->flags|=DCF_ON_TOP;
  if (gr.fp_final_scrn_update)
    (*gr.fp_final_scrn_update)(dc);
  DCDel(dc);

  if (GrScreenSaverUpdate)
    dc=gr.ss;
  else if(gr.scrn_zoom==1) {
    dc=gr.dc2;
  } else {
    GrZoomInScrn;
    dc=gr.zoomed_dc;
  }
    
  if(IsCmdLineMode2) {
    GrUpdateTextModeText;
  } else
    UpdateScreen(dc->body,dc->width,dc->height,dc->width_internal);
  MemCpy(gr.scrn_image->body,dc->body,dc->width_internal*dc->height);
  
  return TRUE;
}
