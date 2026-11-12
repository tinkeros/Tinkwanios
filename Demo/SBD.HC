public extern Bool BlkDevInit(CBlkDev *bd);

U0 TestMountSerial()
{
  I64 drv_let,type,unit,prt_num,make_free,whole_drv;
  CBlkDev *bd;
  drv_let=Let2Let('S');
  type=Let2BlkDevType(drv_let);
  make_free=FALSE;
  whole_drv=FALSE;
  unit=0;
  prt_num=I64_MIN;
  bd=BlkDevNextFreeSlot('S',type);
  bd->unit=unit;
  //BlkDevAdd(bd,prt_num,whole_drive,make_free);
  CDrv *dv;
  CMasterBoot mbr;
  bd->bd_signature=BD_SIGNATURE_VAL;
  "HERE dv=DrvMakeFreeSlot\n";
  Sleep(1000);
  if (make_free)
    dv=DrvMakeFreeSlot(bd->first_drv_let);
  else
    dv=DrvMakeFreeSlot(DrvNextFreeLet(bd->first_drv_let));
  dv->bd=bd;
  dv->drv_offset=bd->drv_offset;
  dv->size=bd->max_blk+1-bd->drv_offset;
  dv->dv_signature=DRV_SIGNATURE_VAL; //Temporarily validate
  "HERE BlkDevInit\n";
  Sleep(1000);
  if (!BlkDevInit(bd))
  {
    dv->dv_signature=0; //Revoke validation
    "Init failed, revoking!\n";
  }
  else
  {
    dv->dv_signature=0; //Revoke validation
    "Init ok, check MBR\n";
    if (bd->read_func)
    {
      (*bd->read_func)(&mbr,0,1);
      if (mbr.signature!=0xAA55)
      {
        "MBR read failure\n";
      }
      else
        "MBR check ok\n";
    }
    else
    {
      "No bd-read_func set!\n";
    }
  }
}
