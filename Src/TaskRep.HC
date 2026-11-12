#help_index "Info;Task"
U0 TaskRepTask(CTask *task,I64 indent)
{
  CTask *task1;
  "%h*c$$MA,T=\"%08X\",LM=\"Kill(0x%X);\n\",$$ $$BLACK$$#%d$$FG$$ "
	"$$TX,\"%$$Q...\",SCX=16$$\n",indent,CH_SPACE,task,task,task->task_num,
	task->task_title;
  "%h*c%04X:%04X:%08X\n",indent+2,CH_SPACE,
	task->task_flags,task->display_flags,task->win_inhibit;
  task1=task->next_child_task;
  while (task1!=(&task->next_child_task)(U8 *)
	-offset(CTask.next_sibling_task)) {
    TaskRepTask(task1,indent+2);
    task1=task1->next_sibling_task;
  }
}

public U0 TaskRep()
{//Report current tasks on all cores.
  I64 i;
  CCPU *c;
  I64 bl=BreakLock;
  for (i=0;i<mp_cnt;i++) {
    c=&cpu_structs[i];
    "$$PURPLE$$CPU%02X$$FG$$\n",i;
    TaskRepTask(c->seth_task,2);
  }
  if(bl) BreakUnlock;
}

CTask *FindTaskRep(CTask *task,U8 *title)
{//Depth-first search of one core's task tree. See $LK,"FindTaskByTitle",A="MN:FindTaskByTitle"$.
  CTask *task1,*res;
  CTask *sentinel=(&task->next_child_task)(U8 *)
	-offset(CTask.next_sibling_task);
  task1=task->next_child_task;
  while (task1!=sentinel) {
    if (!StrCmp(task1->task_title,title))
      return task1;
    res=FindTaskRep(task1,title);
    if (res)
      return res;
    task1=task1->next_sibling_task;
  }
  return NULL;
}

public CTask *FindTaskCore(I64 core,U8 *title)
{//Find a task by title on one core.
  CCPU *c;
  CTask *res;
  if (core>=mp_cnt) {
    "Core %d does not exist!\n",core;
    return NULL;
  }
  c=&cpu_structs[core];
  res=FindTaskRep(c->seth_task,title);
  return res;
}

public CTask *FindTaskByTitle(U8 *title,Bool inc_self=FALSE)
{//Find a task by its $LK,"task_title",A="MN:CTask"$ across all cores.
  I64 i;
  CTask *res;
  for (i=0;i<mp_cnt;i++) {
    res=FindTaskCore(i,title);
    if (res && (inc_self || res!=Fs))
      return res;
  }
  return NULL;
}
