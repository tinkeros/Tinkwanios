#help_index "Debugging/Heap;Memory/Debugging"
/* The reports TinkerOS's OSTestSuite asks for. The heap log needs no ext[]
hooks because every CMemUsed already carries its callers. MemRep reports the
block pool and task heaps, not TinkerOS's fixed memory map. The firmware and
disk reports refuse rather than throw. */

#define HL_CALLER_DEPTH	2 //caller1,caller2

class CHeapLogEntry
{
  CHeapLogEntry *next;
  I64	size,cnt;
  U8	*caller[HL_CALLER_DEPTH];
};

CHeapCtrl *heaplog_hc_watched=NULL;

public Bool HeapLog(Bool val=ON,CTask *task=NULL)
{//Pick the heap $LK,"HeapLogSizeRep",A="MN:HeapLogSizeRep"$() reports on.
  if (val) {
    if (Bt(&sys_semas[SEMA_HEAPLOG_ACTIVE],0)) {
      "HeapLog Already Active\n";
      return TRUE;
    }
    if (!task) task=Fs;
    if (TaskValidate(task))
      heaplog_hc_watched=task->data_heap;
    else
      heaplog_hc_watched=task;//Actually, not a task, must be a HeapCtrl.
    LBts(&sys_semas[SEMA_HEAPLOG_ACTIVE],0);
    return FALSE;
  }
  if (!LBtr(&sys_semas[SEMA_HEAPLOG_ACTIVE],0)) {
    "HeapLog Not Active\n";
    return FALSE;
  }
  heaplog_hc_watched=NULL;
  return TRUE;
}

CHeapLogEntry *HeapLogCollect(CHeapCtrl *hc,CHeapCtrl *scratch,I64 *_total)
{//Snapshot hc's live allocations, aggregated by (size,callers).
  CHeapCtrlArena *arena;
  CMemUsed *used,*head;
  CHeapLogEntry *lst=NULL,*e;
  I64 a,total=0;
  Bool found;
  while (LBts(&hc->locked_flags,1))
    Sleep(1);
  for (a=0;a<16;a++) {
    arena=&hc->arenas[a];
    head=&arena->used_mem;
    used=head->next;
    while (used!=head) {
      total+=used->size;
      found=FALSE;
      e=lst;
      while (e && !found) {
	if (e->size==used->size &&
	    e->caller[0]==used->caller1 && e->caller[1]==used->caller2) {
	  e->cnt++;
	  found=TRUE;
	}
	e=e->next;
      }
      if (!found) {
	e=MAlloc(sizeof(CHeapLogEntry),scratch);
	e->size=used->size;
	e->cnt=1;
	e->caller[0]=used->caller1;
	e->caller[1]=used->caller2;
	e->next=lst;
	lst=e;
      }
      used=used->next;
    }
  }
  LBtr(&hc->locked_flags,1);
  *_total=total;
  return lst;
}

public U0 HeapLogSizeRep(Bool leave_it=OFF)
{//Live allocations of the heap $LK,"HeapLog",A="MN:HeapLog"$() picked, by size.
  CHeapCtrl *hc=heaplog_hc_watched,*scratch,*old;
  CHeapLogEntry *lst,*e;
  CDoc *doc;
  I64 i,total=0;
  if (!Bt(&sys_semas[SEMA_HEAPLOG_ACTIVE],0) || !hc) {
    "HeapLog Not Active\n";
    return;
  }
  old=Fs->data_heap;
  scratch=HeapCtrlInit(NULL,Fs,0);
  doc=DocNew;
  Fs->data_heap=scratch;
  lst=HeapLogCollect(hc,scratch,&total);
  Fs->data_heap=old;
  DocPrint(doc,"$$WW,0$$");
  e=lst;
  while (e) {
    DocPrint(doc,"%08X*%08X=%08X",e->size,e->cnt,e->size*e->cnt);
    for (i=0;i<HL_CALLER_DEPTH;i++)
      DocPrint(doc,"%P",e->caller[i]);
    DocPrint(doc,"\n");
    e=e->next;
  }
  DocPrint(doc,"\n$$LTRED$$Total:%08X$$FG$$\n",total);
  DocInsDoc(DocPut(Fs),doc);
  HeapCtrlDel(scratch);
  if (!leave_it)
    HeapLog(OFF);
}

public U0 HeapLogAddrRep(Bool leave_it=OFF)
{//Live allocations of the heap $LK,"HeapLog",A="MN:HeapLog"$() picked, by address.
  CHeapCtrl *hc=heaplog_hc_watched,*scratch,*old;
  CHeapCtrlArena *arena;
  CMemUsed *used,*head;
  CDoc *doc;
  I64 a,total=0;
  if (!Bt(&sys_semas[SEMA_HEAPLOG_ACTIVE],0) || !hc) {
    "HeapLog Not Active\n";
    return;
  }
  old=Fs->data_heap;
  scratch=HeapCtrlInit(NULL,Fs,0);
  doc=DocNew;
  Fs->data_heap=scratch;
  DocPrint(doc,"$$WW,0$$");
  while (LBts(&hc->locked_flags,1))
    Sleep(1);
  for (a=0;a<16;a++) {
    arena=&hc->arenas[a];
    head=&arena->used_mem;
    used=head->next;
    while (used!=head) {
      DocPrint(doc,"$$PURPLE$$%08X$$FG$$%08X%P%P\n",
	used->size,used+1,used->caller1,used->caller2);
      total+=used->size;
      used=used->next;
    }
  }
  LBtr(&hc->locked_flags,1);
  Fs->data_heap=old;
  DocPrint(doc,"\n$$LTRED$$Total:%08X$$FG$$\n",total);
  DocInsDoc(DocPut(Fs),doc);
  HeapCtrlDel(scratch);
  if (!leave_it)
    HeapLog(OFF);
}

#help_index "Memory/Info;Info"
U0 MemRepTask(CTask *task,I64 indent)
{//One task's heaps. Recurses over its children.
  CTask *task1;
  CHeapCtrl *ch=task->code_heap,*dh=task->data_heap;
  I64 c_a=0,c_u=0,d_a=0,d_u=0;
  if (ch) { c_a=ch->alloced_u8s; c_u=ch->used_u8s; }
  if (dh) { d_a=dh->alloced_u8s; d_u=dh->used_u8s; }
  "%h*c$$MA,T=\"%08X\",LM=\"Kill(0x%X);\n\"$$ code:%08X/%08X data:%08X/%08X "
  "$$TX,\"%$$Q...\",SCX=16$$\n",
	indent,CH_SPACE,task,task,c_u,c_a,d_u,d_a,task->task_title;
  task1=task->next_child_task;
  while (task1!=(&task->next_child_task)(U8 *)
	-offset(CTask.next_sibling_task)) {
    MemRepTask(task1,indent+2);
    task1=task1->next_sibling_task;
  }
}

public U0 MemRep()
{//Memory usage. Shows used/alloced per task heap.
  CCPU *c;
  I64 i,bl=BreakLock;
  "$$WW,0$$$$LTBLUE$$Task Heaps$$FG$$ (used/alloced)\n";
  for (i=0;i<mp_cnt;i++) {
    c=&cpu_structs[i];
    "$$PURPLE$$CPU%02X$$FG$$\n",i;
    MemRepTask(c->seth_task,2);
  }
  if (bl) BreakUnlock;
}

#help_index "Info"
U0 NoHostHardware(U8 *what)
{//Shared message for the reports a hosted process cannot answer.
  "$$LTRED$$%s$$FG$$ is not available in Tinkwanios: it reads real hardware\n"
  "that a hosted process does not have. Run it under TinkerOS proper.\n",what;
}

public U0 SysRepLite()   {NoHostHardware("SysRepLite");}   //SMBIOS tables
public U0 BIOSRep()      {NoHostHardware("BIOSRep");}      //SMBIOS tables
public U0 PCIRep()       {NoHostHardware("PCIRep");}       //PCI config space
public U0 MemBIOSRep()   {NoHostHardware("MemBIOSRep");}   //E820 map
public U0 MemPageRep()   {NoHostHardware("MemPageRep");}   //page tables
public U0 DskChk()       {NoHostHardware("DskChk");}       //RedSea on a blkdev
public U0 DskView()      {NoHostHardware("DskView");}      //raw blkdev sectors
public U0 DrvView()      {NoHostHardware("DrvView");}      //mounted drive table
#help_index ""
