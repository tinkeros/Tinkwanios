#ifndef ACPI_EC_HC
U8 *fan_inc_dir=DirCur;Cd(__DIR__);;
#include "EC"
Cd(fan_inc_dir);Free(fan_inc_dir);;
#endif

#define FAN_HC			1

#define TP_EC_FAN_STATUS	0x2F
#define TP_EC_FAN_SELECT	0x31
#define TP_EC_FAN_RPM_LO	0x84
#define TP_EC_FAN_RPM_HI	0x85

#define TP_EC_THERM_BASE0	0x78
#define TP_EC_THERM_BASE8	0xC0
#define TP_THERM_SENSORS	16

#define TP_FAN_LEVEL_MASK	0x07
#define TP_FAN_FULLSPEED	0x40
#define TP_FAN_AUTO		0x80

#define TP_FAN_LEVEL_MAX	7

#define TP_THERM_NA		-128

#define FAN_PANIC_TEMP		88

I64 FanStatusRd()
{//Raw 0x2F status byte, or -1 if the EC did not answer.
  I64 v;
  if (!EcRd(TP_EC_FAN_STATUS,&v))
    return -1;
  return v;
}

I64 FanRpm()
{//Tachometer in RPM, or -1 if the EC did not answer.
  I64 lo,hi;
  if (!EcRd(TP_EC_FAN_RPM_LO,&lo))
    return -1;
  if (!EcRd(TP_EC_FAN_RPM_HI,&hi))
    return -1;
  return (hi<<8)+lo;
}

I64 FanLevel()
{//Current level 0-7, or -1 unknown.
  I64 s=FanStatusRd();
  if (s<0)
    return -1;
  return s & TP_FAN_LEVEL_MASK;
}

I64 TempGet(I64 idx)
{//Sensor idx 0-15 in degrees C, or TP_THERM_NA if absent.
  I64 v,off;
  if (idx<0 || idx>=TP_THERM_SENSORS)
    return TP_THERM_NA;
  if (idx<8)
    off=TP_EC_THERM_BASE0+idx;
  else
    off=TP_EC_THERM_BASE8+idx-8;
  if (!EcRd(off,&v))
    return TP_THERM_NA;
  if (v & 0x80)
    v-=0x100;
  if (!v)
    return TP_THERM_NA;
  return v;
}

I64 TempMax()
{//Hottest live sensor, or TP_THERM_NA if nothing readable.
  I64 i,t,max=TP_THERM_NA;
  for (i=0;i<TP_THERM_SENSORS;i++)
  {
    t=TempGet(i);
    if (t!=TP_THERM_NA && t>max)
      max=t;
  }
  return max;
}

U0 FanStatusStr(I64 s,I8 *dst)
{//Decode the status byte into something readable.
  if (s<0)
  {
    StrCpy(dst,"unreadable");
    return;
  }
  if (s & TP_FAN_AUTO)
    StrPrint(dst,"auto (level %d)",s & TP_FAN_LEVEL_MASK);
  else if (s & TP_FAN_FULLSPEED)
    StrPrint(dst,"full speed / disengaged");
  else
    StrPrint(dst,"manual level %d",s & TP_FAN_LEVEL_MASK);
}

public U0 TempRep()
{//All thermal sensors.  Sensor 0 is the CPU.
  I64 i,t,n=0;
  EcInit;
  "Thermal sensors\n";
  for (i=0;i<TP_THERM_SENSORS;i++)
  {
    t=TempGet(i);
    if (t!=TP_THERM_NA)
    {
      if (!i)
	"  %2d (EC %02X): %3d C   CPU\n",i,TP_EC_THERM_BASE0,t;
      else if (i<8)
	"  %2d (EC %02X): %3d C\n",i,TP_EC_THERM_BASE0+i,t;
      else
	"  %2d (EC %02X): %3d C\n",i,TP_EC_THERM_BASE8+i-8,t;
      n++;
    }
  }
  if (!n)
    "  none readable, check the offsets against ec_fan_probe.py\n";
  else
    "  hottest: %d C\n",TempMax();
}

public U0 FanRep()
{//Fan plus temperatures, the everyday report.
  I64 s,rpm;
  I8 desc[64];
  EcInit;
  s=FanStatusRd();
  if (s<0)
  {
    "The EC (ports %04X/%04X) did not answer.\n",ec_cmd_port,ec_dat_port;
    return;
  }
  rpm=FanRpm();
  FanStatusStr(s,desc);
  "Fan\n";
  "  EC %02X status: %02X  %s\n",TP_EC_FAN_STATUS,s,desc;
  if (rpm>=0)
    "  tachometer  : %d RPM\n",rpm;
  else
    "  tachometer  : unreadable\n";
  '\n';
  TempRep;
}

public U0 FanWatch()
{//Live monitor.  Any key quits.
  I64 s,rpm,i,t;
  I8 desc[64];
  EcInit;
  "Fan and thermals, press any key to stop.\n\n";
  while (!ScanKey)
  {
    s=FanStatusRd();
    rpm=FanRpm();
    FanStatusStr(s,desc);
    "%4d RPM  %-24s ",rpm,desc;
    for (i=0;i<TP_THERM_SENSORS;i++)
    {
      t=TempGet(i);
      if (t!=TP_THERM_NA)
	"%3d ",t;
    }
    '\n';
    Sleep(1000);
  }
}

#define FAN_ALLOW_CONTROL	1

Bool FanCtrlOk()
{//Common gate for every write path.
  if (FAN_ALLOW_CONTROL)
    return TRUE;
  "Fan control is disabled.  Confirm the EC offsets with ec_fan_probe.py,\n"
  "then set FAN_ALLOW_CONTROL to 1 in Demo/Lenovo/T4xx/Fan.HC.\n";
  return FALSE;
}

Bool FanSetRaw(I64 val)
{//Write the status byte.  No interpretation, no safety net.
  if (!FanCtrlOk())
    return FALSE;
  EcInit;
  return EcWr(TP_EC_FAN_STATUS,val);
}

public Bool FanSetAuto()
{//Hand the fan back to the firmware.  Always safe to call.
  if (!FanCtrlOk())
    return FALSE;
  EcInit;
  return EcWr(TP_EC_FAN_STATUS,TP_FAN_AUTO);
}

public Bool FanSetFullSpeed()
{//Disengage the governor, spin up all the way.  Loud, but never unsafe.
  if (!FanCtrlOk())
    return FALSE;
  EcInit;
  return EcWr(TP_EC_FAN_STATUS,TP_FAN_FULLSPEED);
}

public Bool FanSetLevel(I64 level)
{//Manual level 0-7.  Level 0 stops the fan; that is your problem to manage.
  if (level<0 || level>TP_FAN_LEVEL_MAX)
  {
    "Level must be 0 to %d.  FanSetFullSpeed for maximum.\n",
      TP_FAN_LEVEL_MAX;
    return FALSE;
  }
  if (!FanCtrlOk())
    return FALSE;
  EcInit;
  return EcWr(TP_EC_FAN_STATUS,level);
}

#define FAN_T0			45
#define FAN_T1			55
#define FAN_T2			62
#define FAN_T3			70
#define FAN_T4			78

I64 FanLevelForTemp(I64 t)
{//The curve itself.  Deliberately dull and easy to edit.
  if (t==TP_THERM_NA)
    return -1;
  if (t>=FAN_PANIC_TEMP)
    return TP_FAN_LEVEL_MAX;
  if (t>=FAN_T4)
    return 7;
  if (t>=FAN_T3)
    return 5;
  if (t>=FAN_T2)
    return 4;
  if (t>=FAN_T1)
    return 3;
  if (t>=FAN_T0)
    return 2;
  return 1;
}

public U0 FanCurve()
{//Software fan governor.  Any key stops it and hands the fan back.
  I64 t,level,last=-1;
  if (!FanCtrlOk())
    return;
  EcInit;
  t=TempMax();
  if (t==TP_THERM_NA)
  {
    "No thermal sensors readable, refusing to drive the fan blind.\n";
    return;
  }
  "Software fan curve running, press any key to stop.\n";
  while (!ScanKey)
  {
    t=TempMax();
    if (t==TP_THERM_NA)
    {
      "Lost the thermal sensors, going back to auto.\n";
      FanSetAuto;
      return;
    }
    if (t>=FAN_PANIC_TEMP)
    {
      "%d C, over the panic threshold, going back to auto.\n",t;
      FanSetAuto;
      return;
    }
    level=FanLevelForTemp(t);
    if (level!=last)
    {
      "%3d C -> level %d (%d RPM)\n",t,level,FanRpm();
      if (!FanSetLevel(level))
      {
	"EC write failed, going back to auto.\n";
	FanSetAuto;
	return;
      }
      last=level;
    }
    Sleep(2000);
  }
  "Stopped, fan back to auto.\n";
  FanSetAuto;
}
