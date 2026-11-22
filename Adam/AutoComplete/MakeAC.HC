Bool ac_show_history=FALSE;
Bool ac_history_dirty=TRUE;
I64  ac_history_cnt=0;
U8  *ac_history_items[AC_HISTORY_MAX];
I64  ac_history_lock=0;
#include "Adam/AutoComplete/ACFill.HC"
#include "Adam/AutoComplete/ACTask.HC"
#include "Adam/AutoComplete/ACInit.HC"
