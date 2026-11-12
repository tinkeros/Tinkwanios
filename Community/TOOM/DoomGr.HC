/**
 * Tinkwanios has 256 palette entries (Src/PalGen.HC), 0..229 real and 0xFF
 * TRANSPARENT, so each Doom color takes the nearest one and is drawn solid.
 * This used to dither two of the 16 CGA colors 2x2 to fake the rest.
 *
 * The 2x2 block stays -- it is what puts Doom's 320x200 on a 640x480 screen --
 * but all four pixels are now one color, so callers that store a block as two
 * U16s are unchanged.
 */

U32 class CRGB {
  U8 r,g,b,a;
};

static U8 *doom_palette_mapped=NULL;

U8 *MapPalette(CRGB *data) {
  U8 *ret=MAlloc(256);
  I64 i;
  for(i=0;i!=256;i++) {
    if(!data[i].a)
      ret[i]=GetNearestColorNum(data[i].r,data[i].g,data[i].b);
    else
      ret[i]=TRANSPARENT;
  }
  ret[TRANSPARENT]=TRANSPARENT;
  return ret;
}

CDC *PaletteizeImage(I64 w,I64 h,U8 *px_data) {
  CDC *ret=DCNew(w*2,h*2);
  DCFill(ret,TRANSPARENT);
  I64 x,y;
  for(y=0;y!=h;y++) {
    for(x=0;x!=w;x++) {
      if(*px_data!=TRANSPARENT) {
        ret->color=*px_data;
        GrPlot(ret,x*2,y*2);
        GrPlot(ret,x*2+1,y*2);
        GrPlot(ret,x*2,y*2+1);
        GrPlot(ret,x*2+1,y*2+1);
      }
      px_data++;
    }
  }
  return ret;
}

class CDoomImage {
  I16 w,h,left,top;
  I32 col_offs[0];
};

class CDoomImageCol {
  U8 rowstart,px_cnt,silly_bye;
  U8 data[0];
};

//https://doomwiki.org/wiki/Picture_format
CDC *ReadDoomImage(CDoomImage *header) {
  I64 w=header->w,h=header->h,rowstart,i,j,px_cnt;
  U8 *ptr;
  U8 *pdata=CAlloc(w*h);
  for(i=0;i!=w;i++)
    for(j=0;j!=h;j++)
      pdata[j*w+i]=TRANSPARENT;
  for(i=0;i!=w;i++) {
    ptr=header(U8*)+header->col_offs[i];
    rowstart=0;
    while(rowstart!=255) {
      rowstart=*ptr++;
      if(rowstart==255) break;
      px_cnt=*ptr++;
      if(!px_cnt) throw('Poop');
      ptr++;
      for(j=0;j!=px_cnt;j++) {
        pdata[(j+rowstart)*w+i]=doom_palette_mapped[*ptr++];
      }
      ptr++;
    }
  }
  ptr=PaletteizeImage(w,h,pdata);
  Free(pdata);
  ptr(CDC*)->x=header->left;
  ptr(CDC*)->y=header->top;
  return ptr;
}

CDC *ReadDoomFlat(U8 *flat,CRGB *pal) {
  I64 len;
  CDC *ret;
  U8 *px=CAlloc(64*64);
  for(len=64*64-1;len>=0;len--)
    px[len]=doom_palette_mapped[flat[len]];
  ret=PaletteizeImage(64,64,px);
  Free(px);
  return ret;
}
CRGB *LoadPLAYPALFromLump(U8 *lump) {
  CRGB *ret=CAlloc(sizeof(CRGB)*256);
  I64 cnt;
  for(cnt=0;cnt!=256;cnt++) {
    ret[cnt].r=*lump++;
    ret[cnt].g=*lump++;
    ret[cnt].b=*lump++;
  }
  Free(doom_palette_mapped);
  doom_palette_mapped=MapPalette(ret);
  return ret;
}
U32 godmode_mat[0x100];
U32 light_mat[0x100][16];

//A block is four identical bytes so callers can still store it as two U16s.
U0 BlockSet(U32 *dst,I64 color) {
  dst->u8[0]=color;
  dst->u8[1]=color;
  dst->u8[2]=color;
  dst->u8[3]=color;
}

U32 LookupLighting(U16 px,I64 light,F64 distance,Bool god_mode=FALSE) {
  I64 color=px&0xff;
  if(color==TRANSPARENT)
    return 0xffffffff;//4 TRANSPARENTs
  light=light-distance*1/16.;
  if(light<15)
   light=15;
  else if(light>255)
   light=255;
  if(god_mode)
    return godmode_mat[color];
  return light_mat[color][light>>4]; //>>4 is divide by 16 (256/16==16)
}

U0 InitGodmodeTable() {
  I64 c,lum;
  CBGR24 src;
  for(c=0;c!=0x100;c++) {
    if(c==TRANSPARENT) {
      BlockSet(&godmode_mat[c],TRANSPARENT);
    } else {
      src=gr_palette[c];
//Invulnerability is an inverted greyscale.
      lum=255-ToI64(0.299*src.r+0.587*src.g+0.114*src.b);
      lum=ClampI64(lum,0,255);
      BlockSet(&godmode_mat[c],GetNearestColorNum(lum,lum,lum));
    }
  }
}

//Dimming matches on hue first. Straight nearest sends a dim brown to grey:
//the palette steps are 0x33 apart, so all three channels land on one step.
#define PAL_USED 230
I64 NearestDim(I64 r,I64 g,I64 b) {
  I64 i,best=0;
  F64 lum,cr,cg,cb,pl,d,bd=1e100;
  CBGR24 c;
  lum=ToF64(r+g+b)/3.;
  cr=ToF64(r)-lum;
  cg=ToF64(g)-lum;
  cb=ToF64(b)-lum;
  for(i=0;i!=PAL_USED;i++) {
    c=gr_palette[i];
    pl=ToF64(c.r+c.g+c.b)/3.;
    d=Sqr(pl-lum)+4.*(Sqr(ToF64(c.r)-pl-cr)+
          Sqr(ToF64(c.g)-pl-cg)+Sqr(ToF64(c.b)-pl-cb));
    if(d<bd) { bd=d; best=i; }
  }
  return best;
}

U0 InitLightTable() {
  I64 c,l,r,g,b;
  F64 f;
  CBGR24 src;
  for(c=0;c!=0x100;c++) {
    src=gr_palette[c];
    for(l=0;l!=16;l++) {
      if(c==TRANSPARENT) {
        BlockSet(&light_mat[c][l],TRANSPARENT);
      } else if(l==15) {
        BlockSet(&light_mat[c][l],c);
      } else {
//Gamma, not a linear scale; the palette has nothing between 0 and 0x33.
        f=Sqrt(ToF64(5+l)/20.);
        r=ClampI64(ToI64(src.r*f),0,255);
        g=ClampI64(ToI64(src.g*f),0,255);
        b=ClampI64(ToI64(src.b*f),0,255);
        BlockSet(&light_mat[c][l],NearestDim(r,g,b));
      }
    }
  }
}
InitLightTable;
InitGodmodeTable;
