#define ACPI_EC_HC		1

#define ACPI_HDR_LEN		36
#define ACPI_MAX_TBL_LEN	0x100000
#define ACPI_SCAN_STRIDE	4

#define ACPI_BIOS_LO		0x000E0000
#define ACPI_BIOS_HI		0x00100000
#define ACPI_LOWRAM_LO		0x00100000
#define ACPI_LOWRAM_HI		0x08000000

#define E820_ACPI_RECLAIM	3
#define E820_ACPI_NVS		4

class CAcpiHdr
{//Standard ACPI description header, head of every table.
  U8	signature[4];
  U32	length;
  U8	revision;
  U8	checksum;
  U8	oem_id[6];
  U8	oem_table_id[8];
  U32	oem_revision;
  U8	asl_compiler_id[4];
  U32	asl_compiler_revision;
};

class CAcpiGas
{//Generic Address Structure.
  U8	space_id;
  U8	bit_width;
  U8	bit_offset;
  U8	access_size;
  U64	address;
};

class CAcpiEcdt
{//Embedded Controller Boot Resources Table.
  CAcpiHdr	hdr;
  CAcpiGas	ec_control;
  CAcpiGas	ec_data;
  U32		uid;
  U8		gpe_bit;
  U8		ec_id;
};

#define FADT_DSDT_OFF		40
#define FADT_X_DSDT_OFF 	140

Bool AcpiHdrOk(U8 *p,U8 *sig)
{//Signature match, sane length, and the header checksum sums to zero.
  CAcpiHdr *h=p;
  I64 i,csum=0;
  if (MemCmp(h->signature,sig,4))
    return FALSE;
  if (h->length<ACPI_HDR_LEN || h->length>ACPI_MAX_TBL_LEN)
    return FALSE;
  for (i=0;i<h->length;i++)
    csum+=p[i];
  if (csum & 0xFF)
    return FALSE;
  return TRUE;
}

U8 *AcpiFindInRange(U8 *sig,I64 start,I64 stop,U8 *after=NULL)
{//Brute force scan of [start,stop) for a valid table, skipping past 'after'.
  I64 a,phys=mem_physical_space(I64);
  if (stop>phys)
    stop=phys;
  if (after && start<=after(I64))
    start=after(I64)+1;
  start=(start+ACPI_SCAN_STRIDE-1) & (-ACPI_SCAN_STRIDE);
  a=start;
  while (a+ACPI_HDR_LEN<stop)
  {
    if (AcpiHdrOk(a(U8 *),sig))
      return a(U8 *);
    a+=ACPI_SCAN_STRIDE;
  }
  return NULL;
}

U8 *AcpiFindTable(U8 *sig,U8 *after=NULL)
{//Find a table by signature, the next one after a previous hit.
  CMemE820 *m20=MEM_E820;
  U8 *res;
  I64 base,lim;
  Bool any=FALSE;
  while (m20->type)
  {
    if (m20->type==E820_ACPI_RECLAIM || m20->type==E820_ACPI_NVS)
    {
      any=TRUE;
      base=m20->base(I64);
      lim=base+m20->len;
      res=AcpiFindInRange(sig,base,lim,after);
      if (res)
	return res;
    }
    m20++;
  }
  if (!any)
  {
    res=AcpiFindInRange(sig,ACPI_BIOS_LO,ACPI_BIOS_HI,after);
    if (res)
      return res;
    return AcpiFindInRange(sig,ACPI_LOWRAM_LO,ACPI_LOWRAM_HI,after);
  }
  return NULL;
}

U0 AcpiSigStr(U8 *p,I8 *dst)
{//Copy a four char signature out as a string.
  MemCpy(dst,p,4);
  dst[4]=0;
}

U8 *AcpiDsdt()
{//DSDT address out of the FADT, preferring the 64 bit pointer.
  U8 *facp=AcpiFindTable("FACP");
  CAcpiHdr *h;
  U64 *xp;
  U32 *lop;
  I64 addr;
  if (!facp)
    return AcpiFindTable("DSDT");
  h=facp;
  if (h->length>=FADT_X_DSDT_OFF+8)
  {
    xp=facp+FADT_X_DSDT_OFF;
    addr=*xp;
    if (addr && AcpiHdrOk(addr(U8 *),"DSDT"))
      return addr(U8 *);
  }
  if (h->length>=FADT_DSDT_OFF+4)
  {
    lop=facp+FADT_DSDT_OFF;
    addr=*lop;
    if (addr && AcpiHdrOk(addr(U8 *),"DSDT"))
      return addr(U8 *);
  }
  return AcpiFindTable("DSDT");
}

I64 AmlCntSeq(U8 *tbl,U8 *pat,I64 pat_len)
{//Count occurrences of a byte sequence inside one table.
  CAcpiHdr *h=tbl;
  I64 i,cnt=0,stop;
  if (!tbl)
    return 0;
  stop=h->length-pat_len;
  for (i=0;i<=stop;i++)
    if (!MemCmp(tbl+i,pat,pat_len))
      cnt++;
  return cnt;
}

#define EC_DFT_CMD_PORT 	0x66
#define EC_DFT_DAT_PORT 	0x62
#define EC_CMD_RD		0x80
#define EC_CMD_WR		0x81
#define EC_STS_OBF		0x01
#define EC_STS_IBF		0x02
#define EC_SPIN 		1000000
#define EC_WAIT_MS		100

I64 ec_cmd_port=EC_DFT_CMD_PORT,
    ec_dat_port=EC_DFT_DAT_PORT;
Bool ec_init_done=FALSE;

U0 EcInit()
{//Take the EC ports from the ECDT if the firmware gave us one.
  U8 *ecdt;
  CAcpiEcdt *e;
  if (ec_init_done)
    return;
  ec_init_done=TRUE;
  ecdt=AcpiFindTable("ECDT");
  if (!ecdt)
    return;
  e=ecdt;
  if (e->ec_control.space_id==1 && e->ec_data.space_id==1 &&
      e->ec_control.address && e->ec_data.address)
  {
    ec_cmd_port=e->ec_control.address;
    ec_dat_port=e->ec_data.address;
  }
}

I64 ec_lock_bit=0,ec_lock_depth=0;
CTask *ec_lock_owner=NULL;

U0 EcLock()
{
  if (ec_lock_owner==Fs)
  {
    ec_lock_depth++;
    return;
  }
  while (LBts(&ec_lock_bit,0))
    Yield;
  ec_lock_owner=Fs;
  ec_lock_depth=1;
}

U0 EcUnlock()
{
  if (ec_lock_owner!=Fs)
    return;
  if (!--ec_lock_depth)
  {
    ec_lock_owner=NULL;
    LBtr(&ec_lock_bit,0);
  }
}

Bool EcWait(I64 mask,I64 val)
{//Spin on the EC status register, at most EC_WAIT_MS.
  I64 i;
  F64 end=tS+EC_WAIT_MS/1000.0;
  for (i=0;i<EC_SPIN;i++)
  {
    if ((InU8(ec_cmd_port) & mask)==val)
      return TRUE;
    if (!(i&255) && tS>end)
      break;
  }
  return FALSE;
}

Bool EcRd(I64 addr,I64 *_val)
{//Read one byte of EC address space.  Read only, harmless.
  Bool ok=FALSE;
  EcInit;
  *_val=0;
  EcLock;
  if (EcWait(EC_STS_IBF,0))
  {
    OutU8(ec_cmd_port,EC_CMD_RD);
    if (EcWait(EC_STS_IBF,0))
    {
      OutU8(ec_dat_port,addr);
      if (EcWait(EC_STS_OBF,EC_STS_OBF))
      {
	*_val=InU8(ec_dat_port);
	ok=TRUE;
      }
    }
  }
  EcUnlock;
  return ok;
}

Bool EcRd16(I64 addr,I64 *_val)
{//Little endian 16 bit value at addr, addr+1.
  I64 lo,hi;
  *_val=0;
  if (!EcRd(addr,&lo) || !EcRd(addr+1,&hi))
    return FALSE;
  *_val=hi<<8|lo;
  return TRUE;
}

Bool EcWr(I64 addr,I64 val)
{//Write one byte of EC address space.  NOT safe at a guessed offset.
  Bool ok=FALSE;
  EcInit;
  EcLock;
  if (EcWait(EC_STS_IBF,0))
  {
    OutU8(ec_cmd_port,EC_CMD_WR);
    if (EcWait(EC_STS_IBF,0))
    {
      OutU8(ec_dat_port,addr);
      if (EcWait(EC_STS_IBF,0))
      {
	OutU8(ec_dat_port,val);
	ok=TRUE;
      }
    }
  }
  EcUnlock;
  return ok;
}

U8 ec_snap[256];
Bool ec_snapped=FALSE;

public U0 EcDump()
{//Hex dump of the 256 byte EC address space.
  I64 i,v;
  EcInit;
  "EC cmd port %04X data port %04X\n",ec_cmd_port,ec_dat_port;
  for (i=0;i<256;i++)
  {
    if (!(i & 15))
      "\n%02X: ",i;
    if (EcRd(i,&v))
      "%02X ",v;
    else
      "?? ";
  }
  '\n';
}

public U0 EcSnap()
{//Save the EC address space so EcDiff can tell you what moved.
  I64 i,v;
  EcInit;
  for (i=0;i<256;i++)
  {
    if (EcRd(i,&v))
      ec_snap[i]=v;
    else
      ec_snap[i]=0;
  }
  ec_snapped=TRUE;
  "EC snapshot taken.\n";
}

public U0 EcDiff()
{//Offsets that changed since EcSnap.
  I64 i,v,n=0;
  if (!ec_snapped)
  {
    "No snapshot, run EcSnap first.\n";
    return;
  }
  for (i=0;i<256;i++)
  {
    if (EcRd(i,&v) && v!=ec_snap[i])
    {
      "%02X: %02X -> %02X\n",i,ec_snap[i],v;
      n++;
    }
  }
  if (!n)
    "Nothing changed.\n";
}

public U0 EcPctCandidates()
{//Offsets holding a plausible percentage.
  I64 i,v,n=0;
  EcInit;
  for (i=0;i<256;i++)
  {
    if (EcRd(i,&v) && v>=1 && v<=100)
    {
      "%02X: %d%% ?\n",i,v;
      n++;
    }
  }
  if (!n)
    "No candidates.\n";
}
