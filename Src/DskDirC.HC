//
// From TinkerOS Kernel/BlkDev/DskDirC.HC. Cdd() is the one you type:
// change directory and list it in one go.
//
public Bool IsFile(U8* filename)
{//Test if file exists
//Args spelled out throughout this file: the stage-1 C compiler does not
//fill defaults for an implicit (no-paren) call, and Src/ is compiled by
//it. Same calls as TinkerOS's, just written out.
  I64 old_silent=Silent(ON), res;
  try {
//Both args spelled out: the stage-1 C compiler will not fill Dir()'s
//second default here. Same call either way.
    res=Dir(filename,FALSE);
  }
  catch {
    res=0;
    Fs->catch_except=TRUE;
  }
  Silent(old_silent);
  return res>0;
}
public Bool IsFileZorNotZ(U8* filename)
{//Test if file exists, trying filename with .Z toggled if not found as-is.
  U8 *altname;
  Bool res=IsFile(filename);
  if (!res)
  {
    altname=ToggleZorNotZ(filename);
    res=IsFile(altname);
    Free(altname);
  }
  return res;
}
public Bool Cdd(U8 *dirname=NULL,Bool make_dirs=FALSE)
{//Change directory and list contents
  if(Cd(dirname,make_dirs))
    return Dir(".",FALSE)>0;
  else
    return FALSE;
}
