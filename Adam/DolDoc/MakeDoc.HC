#help_index "DolDoc"
#help_file "::/Doc/DolDoc"

/*
TempleOS DolDoc's can have "cursor movement" cmds which can move the cursor up
the scrn and layer on existing text.  It can also have callback funs which
supply live, changing text.  For these reasons, you can't assume you know
where the vis portion of the document is and must process much
of the document each time it is placed on the scrn, becoming CPU
intensive on big documents.
See $LK,"::/Doc/DolDocOverview.DD"$
*/

//Hash Types
#define DHT_DOC_CMD	1
#define DHT_DOC_FLAG	2
#define DHT_COLOR	4

public class CDolDocGlbls
{
  CHashTable *hash;
  I64	dft_de_flags		[DOCT_TYPES_NUM],
	type_flags_nontag_invis [(DOCT_TYPES_NUM+63)/64],
	type_flags_form		[(DOCT_TYPES_NUM+63)/64],
	type_flags_data		[(DOCT_TYPES_NUM+63)/64],
	type_flags_chk_dup	[(DOCT_TYPES_NUM+63)/64],
	clean_scan_codes	[4];
  I32	dft_type_flags		[DOCT_TYPES_NUM];
} doldoc;
MemSet(&doldoc,0,sizeof(CDolDocGlbls));

#help_index "God"
#define BIBLE_FILENAME	"::/misc/Bible.TXT.Z"

#include "Adam/DolDoc/DocExt.HC"
#include "Adam/DolDoc/DocBin.HC"
#include "Adam/DolDoc/DocNew.HC"
#include "Adam/DolDoc/DocForm.HC"
#include "Adam/DolDoc/DocDblBuf.HC"
#include "Adam/DolDoc/DocPlain.HC"
#include "Adam/DolDoc/DocInit.HC"
#include "Adam/DolDoc/DocHighlight.HC"
#include "Adam/DolDoc/DocRecalcLib.HC"
#include "Adam/DolDoc/DocRecalc.HC"
#include "Adam/DolDoc/DocFile.HC"
#include "Adam/DolDoc/DocClipBoard.HC"
#include "Adam/DolDoc/DocRun.HC"
#include "Adam/DolDoc/DocGet.HC"
#include "Adam/DolDoc/DocChar.HC"
#include "Adam/DolDoc/DocFind.HC"
#include "Adam/DolDoc/DocLink.HC"
#include "Adam/DolDoc/DocEd.HC"
#include "Adam/DolDoc/DocPopUp.HC"
#include "Adam/DolDoc/DocGr.HC"
#include "Adam/DolDoc/DocMacro.HC"
#include "Adam/DolDoc/DocWidgetWiz.HC"
#include "Adam/DolDoc/DocPutKey.HC"
#include "Adam/DolDoc/DocPutS.HC"
#include "Adam/DolDoc/DocCodeTools.HC"
#include "Adam/DolDoc/DocTree.HC"
#include "Adam/DolDoc/DocTerm.HC"

KeyDevAdd(&KDDocPutKey,&KDDocPutS,0x80000000,TRUE);
fp_getstr2=&DocGetStr2;
fp_doc_put=&DocPut;
