CCmpGlbls	cmp;
#include "OptLib.HC"
#include "CInit.HC"
#include "AsmLib.HC"
#include "CExcept.HC"
#include "LexLib.HC"
#include "Lex.HC"
#include "PrsLib.HC"
#include "PrsVar.HC"
#include "CMisc.HC"
CmpLoadDefines;		
CmpFillTables;
CMiscInit;
#include "TINKWANIOS_PrsExp.HC"
#include "TINKWANIOS_CodeGen.HC"
#include "PrsStmt.HC";
#include "AsmResolve.HC"
#include "CMain.HC"
//TinkwaniosAotCompile("HCRT_TOS.HC","HCRT.BIN")
