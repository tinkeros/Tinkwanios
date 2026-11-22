CCmpGlbls	cmp;
#include "Compiler/OptLib.HC"
#include "Compiler/CInit.HC"
#include "Compiler/AsmLib.HC"
#include "Compiler/CExcept.HC"
#include "Compiler/LexLib.HC"
#include "Compiler/Lex.HC"
#include "Compiler/PrsLib.HC"
#include "Compiler/PrsVar.HC"
#include "Compiler/CMisc.HC"
CmpLoadDefines;		
CmpFillTables;
CMiscInit;
#include "Compiler/TINKWANIOS_PrsExp.HC"
#include "Src/TINKWANIOS_CodeGen.HC"
#include "Compiler/PrsStmt.HC";
#include "Compiler/AsmResolve.HC"
#include "Compiler/CMain.HC"
//TinkwaniosAotCompile("HCRT_TOS.HC","HCRT.BIN")
