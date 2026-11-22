#help_index "Graphics/Color"
public U8 gr_rainbow_10[10]={
  BLACK,BROWN,RED,LTRED,YELLOW,GREEN,BLUE,PURPLE,LTGRAY,WHITE};

DefineLstLoad("ST_RAINBOW_10",
  "BLACK\0BROWN\0RED\0LTRED\0YELLOW\0GREEN\0BLUE\0PURPLE\0LTGRAY\0WHITE\0");

public U0 GrPaletteColorSet(I64 color_num,CBGR48 bgr48)
{//VGA had 6 bits per channel; here the high 8 of each CBGR48 channel are kept.
  gr_palette[color_num].r=bgr48.r.u8[1];
  gr_palette[color_num].g=bgr48.g.u8[1];
  gr_palette[color_num].b=bgr48.b.u8[1];
  __GrPaletteColorSet(color_num,bgr48);
}

public CBGR48 GrPaletteColorGet(I64 color_num)
{
  CBGR48 res=0;
  res.r=(gr_palette[color_num].r|gr_palette[color_num].r<<8)&0xffff;
  res.g=(gr_palette[color_num].g|gr_palette[color_num].g<<8)&0xffff;
  res.b=(gr_palette[color_num].b|gr_palette[color_num].b<<8)&0xffff;
  return res;
}

public CBGR48 gr_palette_std[COLORS_NUM]={
0x000000000000,0x00000000AAAA,0x0000AAAA0000,0x0000AAAAAAAA,
0xAAAA00000000,0xAAAA0000AAAA,0xAAAA55550000,0xAAAAAAAAAAAA,
0x555555555555,0x55555555FFFF,0x5555FFFF5555,0x5555FFFFFFFF,
0xFFFF55555555,0xFFFF5555FFFF,0xFFFFFFFF5555,0xFFFFFFFFFFFF};

public CBGR48 gr_palette_gray[COLORS_NUM]={
0x000000000000,0x111111111111,0x222222222222,0x333333333333,
0x444444444444,0x555555555555,0x666666666666,0x777777777777,
0x888888888888,0x999999999999,0xAAAAAAAAAAAA,0xBBBBBBBBBBBB,
0xCCCCCCCCCCCC,0xDDDDDDDDDDDD,0xEEEEEEEEEEEE,0xFFFFFFFFFFFF};

public CBGR24 gr32_palette_std[COLORS_NUM]={
  0x000000,0x0000AA,0x00AA00,0x00AAAA,0xAA0000,0xAA00AA,0xAA5500,0xAAAAAA,
  0x555555,0x5555FF,0x55FF55,0x55FFFF,0xFF5555,0xFF55FF,0xFFFF55,0xFFFFFF};

public CBGR24 gr32_palette_gray[COLORS_NUM]={
  0x000000,0x111111,0x222222,0x333333,0x444444,0x555555,0x666666,0x777777,
  0x888888,0x999999,0xAAAAAA,0xBBBBBB,0xCCCCCC,0xDDDDDD,0xEEEEEE,0xFFFFFF};

public U0 GrPaletteGet(CBGR48 *bgr48)
{//16 colors
  I64 i;
  for (i=0;i<COLORS_NUM;i++)
    bgr48[i]=GrPaletteColorGet(i);
}

public U0 GrPaletteSet(CBGR48 *bgr48)
{//16 colors
  I64 i;
  for (i=0;i<COLORS_NUM;i++)
    GrPaletteColorSet(i,bgr48[i]);
}

public U0 GrPaletteGet32(CBGR24 *bgr24)
{//16 colors
  ClassCpy(bgr24,gr_palette,COLORS_NUM);
}

public U0 GrPaletteSet32(CBGR24 *bgr24)
{//16 colors
  I64 i;
  for (i=0;i<COLORS_NUM;i++)
    GrSetRGB(i,bgr24[i].r,bgr24[i].g,bgr24[i].b);
}

public U0 GrPaletteFlush()
{//Push all PAL_COLORS_NUM entries at the display. TinkerOS reloads the whole
 //VGA DAC, so the slots nothing has set read back as black there; without
 //this the host would keep its own defaults in them.
  I64 i;
  for (i=0;i<PAL_COLORS_NUM;i++)
    __GrPaletteColorSet(i,GrPaletteColorGet(i));
}

public U0 PaletteSetStd()
{//Activate std palette, plus the extended web-safe colors above it.
  GrPaletteSet(gr_palette_std);
  GrSetExtPalette;
  GrPaletteFlush;
}

public U0 PaletteSetGray()
{//Activate gray palette. The extended colors above 15 are left alone.
  GrPaletteSet(gr_palette_gray);
}

public U0 SetBrightness(U64 p)
{//Sets the default 16 colors scaled by p/100.
  I64 i;
  CBGR48 c;
  for (i=0;i<COLORS_NUM;i++) {
    c=gr_palette_std[i];
    c.r.u8[1]=ClampU64(c.r.u8[1]*p/100,0,255);
    c.g.u8[1]=ClampU64(c.g.u8[1]*p/100,0,255);
    c.b.u8[1]=ClampU64(c.b.u8[1]*p/100,0,255);
    GrPaletteColorSet(i,c);
  }
}
