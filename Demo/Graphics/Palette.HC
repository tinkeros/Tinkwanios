//
// The whole live palette, all PAL_COLORS_NUM entries of it: the 16 CGA colors
// the OS has always had, then the 214 web-safe entries GrSetExtPalette() adds
// above them, then the unused slots and TRANSPARENT. Only possible because a
// pixel is a full 8-bit palette index. See Src/PalGen.HC.
//
U0 PaletteDemo()
{
  CDC *dc=DCAlias;
  I64 i,x,y,w,h,cols=16,rows=16;
  SettingsPush;
  WinMax;
  DCFill(dc,BLACK);
  w=(GR_WIDTH-32)/cols;
  h=(GR_HEIGHT-64)/rows;
  for (i=0;i<PAL_COLORS_NUM;i++)
  {
    x=16+i%cols*w;
    y=32+i/cols*h;
    dc->color=i;
    GrRect(dc,x,y,w-1,h-1);
  }
  dc->color=WHITE;
  GrPrint(dc,16,8,"0-15 CGA, 16-229 web-safe cube, 230-254 free, 255 TRANSPARENT");
  GrPrint(dc,16,GR_HEIGHT-24,"Press a key.");
  DCDel(dc);
  PressAKey;
  SettingsPop;
}

PaletteDemo;
