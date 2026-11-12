#ifndef ACPI_EC_HC
U8 *bat_inc_dir=DirCur;Cd(__DIR__);;
#include "EC"
Cd(bat_inc_dir);Free(bat_inc_dir);;
#endif

#define BATTERY_HC		1

#define AML_PNP0C0A_B0		0x41
#define AML_PNP0C0A_B1		0xD0
#define AML_PNP0C0A_B2		0x0C
#define AML_PNP0C0A_B3		0x0A

I64 AmlCntBatDevs(U8 *tbl)
{//How many PNP0C0A devices this table declares, either encoding.
  U8 eisa[4];
  eisa[0]=AML_PNP0C0A_B0;
  eisa[1]=AML_PNP0C0A_B1;
  eisa[2]=AML_PNP0C0A_B2;
  eisa[3]=AML_PNP0C0A_B3;
  return AmlCntSeq(tbl,eisa,4)+AmlCntSeq(tbl,"PNP0C0A",7);
}

U0 AmlTblRep(U8 *tbl)
{//Two lines saying what battery related names live in this table.
  CAcpiHdr *h=tbl;
  I8 sig[5],oem[7];
  I64 bats,bst,bif,bix,psr;
  if (!tbl)
    return;
  AcpiSigStr(tbl,sig);
  MemCpy(oem,h->oem_id,6);
  oem[6]=0;
  bats=AmlCntBatDevs(tbl);
  bst =AmlCntSeq(tbl,"_BST",4);
  bif =AmlCntSeq(tbl,"_BIF",4);
  bix =AmlCntSeq(tbl,"_BIX",4);
  psr =AmlCntSeq(tbl,"_PSR",4);
  "%s at %010X len %06X oem %s\n",sig,tbl,h->length,oem;
  "    PNP0C0A:%d _BST:%d _BIF:%d _BIX:%d _PSR:%d\n",bats,bst,bif,bix,psr;
}

I64 BatDevCnt()
{//PNP0C0A devices across the DSDT and every SSDT.
  U8 *tbl;
  I64 cnt=0;
  cnt+=AmlCntBatDevs(AcpiDsdt());
  tbl=AcpiFindTable("SSDT");
  while (tbl)
  {
    cnt+=AmlCntBatDevs(tbl);
    tbl=AcpiFindTable("SSDT",tbl);
  }
  return cnt;
}

public U0 BatTblRep()
{//Report the ACPI tables that have anything to do with the battery.
  U8 *dsdt,*ssdt,*ecdt,*facp;
  CAcpiEcdt *e;
  I64 n=0;
  "ACPI table search\n";
  facp=AcpiFindTable("FACP");
  if (facp)
    "FACP at %010X\n",facp;
  else
    "FACP not found\n";
  dsdt=AcpiDsdt();
  if (dsdt)
    AmlTblRep(dsdt);
  else
    "DSDT not found\n";
  ssdt=AcpiFindTable("SSDT");
  while (ssdt)
  {
    n++;
    AmlTblRep(ssdt);
    ssdt=AcpiFindTable("SSDT",ssdt);
  }
  if (!n)
    "No SSDTs found\n";
  ecdt=AcpiFindTable("ECDT");
  if (ecdt)
  {
    e=ecdt;
    "ECDT at %010X cmd port %04X data port %04X gpe %02X\n",
      ecdt,e->ec_control.address,e->ec_data.address,e->gpe_bit;
  }
  else
    "ECDT not found, will assume the legacy 0x66/0x62 ports\n";
}

#define BAT_SMB_ENABLE		0
#define BAT_SMB_BASE		0x00

#define SMB_PRTCL		0
#define SMB_STS 		1
#define SMB_ADDR		2
#define SMB_CMD 		3
#define SMB_DATA		4

#define SMB_PRTCL_READ_WORD	0x09
#define SMB_STS_MASK		0x1F

#define SBS_BAT_ADDR		0x16
#define SBS_VOLTAGE		0x09
#define SBS_CURRENT		0x0A
#define SBS_RSOC		0x0D
#define SBS_REM_CAP		0x0F
#define SBS_FULL_CAP		0x10
#define SBS_BAT_STATUS		0x16

#define SBS_STS_FULLY_DISCH	0x0010
#define SBS_STS_FULLY_CHARGED	0x0020
#define SBS_STS_DISCHARGING	0x0040

Bool BatSmbRdWord(I64 cmd,I64 *_val)
{//One SMBus read-word transaction through the EC mailbox.
  I64 i,v,lo,hi;
  *_val=0;
  if (!BAT_SMB_ENABLE)
    return FALSE;
  if (!EcWr(BAT_SMB_BASE+SMB_ADDR,SBS_BAT_ADDR))
    return FALSE;
  if (!EcWr(BAT_SMB_BASE+SMB_CMD,cmd))
    return FALSE;
  if (!EcWr(BAT_SMB_BASE+SMB_PRTCL,SMB_PRTCL_READ_WORD))
    return FALSE;
  v=1;
  i=0;
  while (i<1000 && v)
  {
    if (!EcRd(BAT_SMB_BASE+SMB_PRTCL,&v))
      return FALSE;
    if (v)
      Sleep(1);
    i++;
  }
  if (v)
    return FALSE;
  if (!EcRd(BAT_SMB_BASE+SMB_STS,&v))
    return FALSE;
  if (v & SMB_STS_MASK)
    return FALSE;
  if (!EcRd(BAT_SMB_BASE+SMB_DATA,&lo))
    return FALSE;
  if (!EcRd(BAT_SMB_BASE+SMB_DATA+1,&hi))
    return FALSE;
  *_val=(hi<<8)+lo;
  return TRUE;
}

#define BAT_EC_SEL_OFF		0x81
#define BAT_EC_WIN		0xA0
#define BAT_EC_STATUS_OFF	0x38
#define BAT_EC_AC_OFF		0x46
#define BAT_EC_AC_MASK		0x10

#define BAT_PG_STATE		0
#define BAT_PG_MODE		1
#define BAT_PG_DESIGN		2
#define BAT_PG_CHEM		4
#define BAT_PG_MFG		5
#define BAT_PG_MODEL		6

#define BAT_HBS_PRESENT		0x80
#define BAT_HBS_CHARGING	0x20
#define BAT_HBS_DISCHG		0x40
#define BAT_HBS_LEVEL		0x0F

#define BAT_MAX			2

class CBatInfo
{
  I64 idx;
  Bool present,
	ready,
	ac,
	charging,discharging,critical,
	mwh;
  I64 hbs,
	pct,
	rem,full,design,
	mv,design_mv,
	ma,
	mw,
	min_empty,
	min_full,
	sbs_status,cycles,serial;
  U8	chem[5],mfg[17],model[17];
};

Bool BatPage(I64 idx,I64 page)
{//Point the 0xA0 window at battery idx, page page.  Caller holds EcLock.
  return EcWr(BAT_EC_SEL_OFF,idx<<4|page);
}

Bool BatWin16(I64 off,I64 *_val)
{//One 16 bit register of the selected page.
  return EcRd16(BAT_EC_WIN+off,_val);
}

U0 BatWinStr(U8 *dst,I64 len)
{//A text page: len bytes, cut at the first NUL, trailing spaces dropped.
  I64 i,v;
  for (i=0;i<len;i++)
  {
    if (!EcRd(BAT_EC_WIN+i,&v) || v<0x20 || v>0x7E)
      break;
    dst[i]=v;
  }
  dst[i]=0;
  while (i && dst[i-1]==' ')
    dst[--i]=0;
}

I64 BatMin(I64 v)
{//SBS minutes; 0xFFFF means "not applicable".
  if (v==0xFFFF)
    return -1;
  return v;
}

public Bool BatInfo(CBatInfo *b,I64 idx=0,Bool ident=FALSE)
{//Fill b for battery idx (0 BAT0, 1 BAT1).  ident: also design figures and names.
  I64 v,sel=-1;
  Bool ok=FALSE;
  MemSet(b,0,sizeof(CBatInfo));
  b->idx=idx;
  b->min_empty=-1;
  b->min_full=-1;
  if (!(0<=idx<BAT_MAX))
    return FALSE;
  EcInit;
  EcLock;
  if (!EcRd(BAT_EC_AC_OFF,&v))
    goto bi_done;
  b->ac=ToBool(v & BAT_EC_AC_MASK);
  if (!EcRd(BAT_EC_STATUS_OFF+idx,&v))
    goto bi_done;
  b->hbs=v;
  b->present=ToBool(v & BAT_HBS_PRESENT);
  b->charging=ToBool(v & BAT_HBS_CHARGING);
  b->discharging=!b->charging && v & BAT_HBS_DISCHG;
  b->ready=b->present && v & BAT_HBS_LEVEL!=BAT_HBS_LEVEL;
  b->critical=b->ready && !(v & BAT_HBS_LEVEL);
  ok=TRUE;
  if (!b->ready)
    goto bi_done;
  EcRd(BAT_EC_SEL_OFF,&sel);
  if (!BatPage(idx,BAT_PG_MODE) || !BatWin16(0,&v))
  {
    ok=FALSE;
    goto bi_done;
  }
  b->mwh=ToBool(v & 0x8000);
  BatWin16(4,&b->cycles);
  if (!BatPage(idx,BAT_PG_STATE))
  {
    ok=FALSE;
    goto bi_done;
  }
  BatWin16(0,&b->rem);
  BatWin16(2,&b->full);
  BatWin16(4,&v);
  b->min_empty=BatMin(v);
  BatWin16(6,&b->pct);
  BatWin16(8,&v);
  if (v & 0x8000)
    v-=0x10000;
  b->ma=v;
  BatWin16(0xA,&b->mv);
  BatWin16(0xC,&v);
  b->min_full=BatMin(v);
  BatWin16(0xE,&b->sbs_status);
  if (b->mwh)
  {
    b->rem*=10;
    b->full*=10;
    b->mw=AbsI64(b->ma)*b->mv/1000;
  }
  if (b->pct>100)
    b->pct=100;
  if (ident)
  {
    if (BatPage(idx,BAT_PG_DESIGN))
    {
      BatWin16(0,&b->design);
      if (b->mwh)
	b->design*=10;
      BatWin16(2,&b->design_mv);
      BatWin16(0xA,&b->serial);
    }
    if (BatPage(idx,BAT_PG_CHEM))
      BatWinStr(b->chem,4);
    if (BatPage(idx,BAT_PG_MFG))
      BatWinStr(b->mfg,16);
    if (BatPage(idx,BAT_PG_MODEL))
      BatWinStr(b->model,16);
  }
bi_done:
  if (sel>=0)
    EcWr(BAT_EC_SEL_OFF,sel);
  EcUnlock;
  return ok;
}

public I64 BatPct()
{//BAT0's charge in percent, -1 if there is no battery or no answer.
  CBatInfo b;
  if (!BatInfo(&b) || !b.ready)
    return -1;
  return b.pct;
}

#define BAT_SRC_NONE		0
#define BAT_SRC_SMBUS		1
#define BAT_SRC_ECRAM		2

I64 BatStatus(I64 *_pct,Bool *_charging,Bool *_pct_ok,Bool *_charging_ok)
{//Percent and charging, from whichever source answers.  Returns it.
  CBatInfo b;
  I64 v,cur,pct;
  *_pct=0;
  *_charging=FALSE;
  *_pct_ok=FALSE;
  *_charging_ok=FALSE;
  if (BAT_SMB_ENABLE)
  {
    if (BatSmbRdWord(SBS_RSOC,&pct) && pct<=100)
    {
      *_pct=pct;
      *_pct_ok=TRUE;
    }
    if (BatSmbRdWord(SBS_BAT_STATUS,&v))
    {
      *_charging=!(v & SBS_STS_DISCHARGING);
      *_charging_ok=TRUE;
    }
    else if (BatSmbRdWord(SBS_CURRENT,&cur))
    {
      if (cur & 0x8000)
	cur-=0x10000;
      *_charging=cur>0;
      *_charging_ok=TRUE;
    }
    if (*_pct_ok || *_charging_ok)
      return BAT_SRC_SMBUS;
  }
  if (!BatInfo(&b) || !b.present)
    return BAT_SRC_NONE;
  *_charging=b.charging;
  *_charging_ok=TRUE;
  if (b.ready)
  {
    *_pct=b.pct;
    *_pct_ok=TRUE;
  }
  return BAT_SRC_ECRAM;
}

U8 *BatCapStr(U8 *dst,I64 v,Bool mwh)
{//"27.81 Wh" or "2781 mAh".
  if (mwh)
    StrPrint(dst,"%d.%02d Wh",v/1000,v%1000/10);
  else
    StrPrint(dst,"%d mAh",v);
  return dst;
}

U8 *BatMinStr(U8 *dst,I64 m)
{
  StrPrint(dst,"%d:%02d",m/60,m%60);
  return dst;
}

U0 BatOneRep(CBatInfo *b)
{
  U8 s1[32],s2[32],s3[32];
  "BAT%d: ",b->idx;
  if (!b->present)
  {
    "not present\n";
    return;
  }
  if (!b->ready)
  {
    "present, the EC has not read it yet (HB%dS %02X)\n",b->idx,b->hbs;
    return;
  }
  "%d%%, ",b->pct;
  if (b->charging)
    "charging";
  else if (b->discharging)
    "discharging";
  else if (b->ac)
    "on AC, not charging";
  else
    "idle";
  if (b->critical)
    ", CRITICAL";
  '\n';
  "  Capacity: %s of %s",BatCapStr(s1,b->rem,b->mwh),
	BatCapStr(s2,b->full,b->mwh);
  if (b->design)
    " (design %s, %d%% left)",BatCapStr(s3,b->design,b->mwh),
	  b->full*100/b->design;
  '\n';
  "  Voltage : %d.%03d V",b->mv/1000,b->mv%1000;
  if (b->design_mv)
    " (nominal %d.%03d V)",b->design_mv/1000,b->design_mv%1000;
  '\n';
  "  Current : %d mA",b->ma;
  if (b->mw)
    ", %d.%02d W",b->mw/1000,b->mw%1000/10;
  '\n';
  if (b->charging && b->min_full>=0)
    "  Full in : %s\n",BatMinStr(s1,b->min_full);
  if (b->discharging && b->min_empty>=0)
    "  Left    : %s\n",BatMinStr(s1,b->min_empty);
  if (*b->model || *b->mfg)
    "  Pack    : %s %s %s, serial %d, %d cycles\n",b->mfg,b->model,b->chem,
	  b->serial,b->cycles;
}

public U0 BatRep(Bool tables=FALSE)
{//Battery state: both slots, with design figures and the pack's name.
  CBatInfo b;
  I64 i,bats;
  if (tables)
  {
    BatTblRep;
    bats=BatDevCnt();
    "%d PNP0C0A battery device(s) declared in AML.\n\n",bats;
  }
  EcInit;
  if (BAT_SMB_ENABLE)
    "(BAT_SMB_ENABLE is set but BatRep reads the EC window; see BatStatus)\n";
  for (i=0;i<BAT_MAX;i++)
  {
    if (!BatInfo(&b,i,TRUE))
    {
      "The EC (ports %04X/%04X) did not answer.\n",ec_cmd_port,ec_dat_port;
      return;
    }
    if (!i)
    {
      "AC adapter: ";
      if (b.ac)
	"plugged in\n";
      else
	"unplugged\n";
    }
    BatOneRep(&b);
  }
}

public U0 BatWatch()
{//BAT0 once a second.  Any key stops.
  CBatInfo b;
  "Battery, press any key to stop.\n";
  while (!ScanKey)
  {
    if (BatInfo(&b) && b.ready)
      "%3d%%  %5d mV  %6d mA  %d.%02d W  AC %d\n",b.pct,b.mv,b.ma,
	    b.mw/1000,b.mw%1000/10,b.ac;
    else
      "no battery reading\n";
    Sleep(1000);
  }
}
