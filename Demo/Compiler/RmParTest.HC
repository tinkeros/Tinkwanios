//
// Self-test for RmParens.HC: run it over a known input and compare the
// result with the expected output byte for byte.
//
// TinkerOS's version of this compares MD5s and needs a writable B: drive;
// Tinkwanios has neither md5() nor DrvMounted(), and a byte compare says
// more when it fails anyway -- it can point at the first difference.
//
Cd(__DIR__);;
#include "RmParens"

U0 RmParTest()
{
  U8 *tmp_file="T:/Tmp/RmParTestCases.HC";
  U8 *buf,*want,*got;
  I64 size,want_size,got_size,i;

  DirMk("T:/Tmp");
  if (!(buf=FileRead("RmParTestCases.HC",&size))) {
    "RmParTest: can't read 'RmParTestCases.HC'\n";
    return;
  }
  FileWrite(tmp_file,buf,size);
  Free(buf);

  RmParens(tmp_file);

  want=FileRead("RmParExpected.HC",&want_size);
  got =FileRead(tmp_file,&got_size);
  if (!want || !got)
    "RmParTest: FAIL -- could not read back the files\n";
  else if (want_size!=got_size)
    "RmParTest: FAIL -- %d bytes, expected %d\n",got_size,want_size;
  else {
    i=0;
    while (i<want_size && want[i]==got[i])
      i++;
    if (i<want_size)
      "RmParTest: FAIL -- first difference at byte %d\n",i;
    else
      "RmParTest: PASS -- %d bytes match RmParExpected.HC\n",got_size;
  }
  Free(want);
  Free(got);
}

RmParTest;
