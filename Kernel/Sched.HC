U64 SYS_CTRL_ALT_FLAGS=0; //In KGlbls?

//Sched.
//This is put in Sched.HC as it use it as a replacement for CLI
Bool BreakLock(CTask *task=NULL)
{//Disables <CTRL-ALT-c>.
  if (!task) task=Fs;
  return !LBts(&task->task_flags,TASKf_BREAK_LOCKED);
}

//Ditto
U0 Break()
{//Send <CTRL-ALT-c>.
  if (Bt(&(Fs->task_flags),TASKf_BREAK_TO_SHIFT_ESC))
    Msg(MSG_KEY_DOWN,CH_SHIFT_ESC,0x20100000201);
  else {
    Fs->wake_jiffy=0;
    TaskRstAwaitingMsg;
    DrvsRelease();
    BlkDevsRelease();
    FlushMsgs;
    throw('Break');
  }
}

//Ditto
Bool BreakUnlock(CTask *task=NULL)
{//Reenables <CTRL-ALT-c> and issues any pending breaks.
  Bool res;
  if (!task) task=Fs;
  res=LBtr(&task->task_flags,TASKf_BREAK_LOCKED);
  if (LBtr(&task->task_flags,TASKf_PENDING_BREAK)) {
    if (task==Fs)
      Break;
    else
      TaskContextSetRIP(task->context_save_area,&Break);
  }
  return res;
}


U0 TaskFocusNext()
{
  CTask *task,*_task=sys_focus_task;
  sys_focus_task=NULL;
  if (!_task) _task=adam_task;
  task=_task->next_task;
  do {
    if (!Bt(&task->win_inhibit,WIf_SELF_FOCUS)) {
      sys_focus_task=task;
      WinToTop(sys_focus_task);
      return;
    }
    task=task->next_task;
  } while (task!=_task);
}
#define TaskContextSave TINKWANIOS_SetJmp(Fs->context_save_area)

//Per core: the task this core is tearing down on somebody else's stack.
//See the note in Yield().
CTask *sched_foreign_teardown[MP_PROCESSORS_NUM];

U0 TaskContextRestore(CTask *task) {
  CBpt *bp;
  //TODO increase Gs->swap_center;
  if(!Bt(&task->task_flags,TASKf_DISABLE_BPTS)) {
    for(bp=task->bpt_lst;bp;bp=bp->next) {
      //https://github.com/scottt/debugbreak 
      *bp->addr=0xd4200000;
    }
  }
  task->swap_cnter++;
//Whatever foreign-stack teardown this core was doing ends here: we are
//leaving that stack for good.
  sched_foreign_teardown[Gs->num]=NULL;
  SetFs(task);
  TINKWANIOS_LongJmp(task->context_save_area);
}
extern CTask *TaskEnd(); 
U0 Yield() {
  CTask *task=Fs;
  CBpt *bp;
//A task may only ever save a scheduler context that describes its OWN stack.
//
//A killed task is torn down inside the *killer's* Yield -- the scan below
//does SetFs(task);TaskEnd() -- so TaskEnd, the task_end_cb it calls, and the
//Exit;Yield; after it all run with Fs set to the dying task while the stack
//underneath still belongs to the task that was yielding.  TaskContextSave
//there records that foreign rsp/rbp in the dying task's context_save_area,
//and the task_end_cb branch has just cleared TASKf_KILL_TASK, so the
//scheduler is free to restore it: the task would then run on the other
//task's stack and quietly overwrite its live frames.
//
//Measured by printing here when ChkOnStk(GetRSP,task) fails (exempting the
//Adam and per-core tasks, which legitimately run on a host thread stack):
//a Misc/OSTestSuite.HC run hits it ~30 times in the first two minutes, from
//AutoComplete and the sound tasks, which are the ones carrying a
//task_end_cb.  Nothing was seen resuming onto a foreign stack, so this is a
//latent hazard rather than an observed corruption -- it is not what caused
//the "StrCpy+0x0065 <- ExeCmdLine+0x04EE" fault, which was the varargs
//stack leak fixed in Compiler/TINKWANIOS_PrsExp.HC.
//
//Skip only the save in that case.  Everything else -- picking the next task
//and switching to it -- has to stay as it was, because Exit's Yield must not
//return: an earlier attempt that returned let TaskEnd run to completion and
//the scheduler then walked the ring from a freed CTask, faulting in
//TaskKillDying.
  Bool foreign_stk=sched_foreign_teardown[Gs->num]==task;
  Gs->last_yield=cnts.jiffies=__GetTicks;
  if(!Bt(&task->task_flags,TASKf_DISABLE_BPTS)) {
    for(bp=task->bpt_lst;bp;bp=bp->next) {
      *bp->addr=bp->val;
    }
  }
  if(!foreign_stk) {
    if(TaskContextSave) {
      return;
    }
  }
  if(SYS_CTRL_ALT_FLAGS
    &(1<<CTRL_ALT_DEL|1<<CTRL_ALT_TAB|1<<CTRL_ALT_X|1<<CTRL_ALT_C)) {
    if(Gs->num) {
      goto restore;
    }
    if(LBtr(&SYS_CTRL_ALT_FLAGS,CTRL_ALT_TAB)) {
      if(sys_focus_task) {
        TaskFocusNext;
        goto restore;
      }
    }
    if(LBtr(&SYS_CTRL_ALT_FLAGS,CTRL_ALT_X)&&sys_focus_task) {
      LBts(&sys_focus_task->task_flags,TASKf_KILL_TASK);
      task=sys_focus_task;
      SetFs(sys_focus_task);
//As in the kill scan below: TaskEnd() runs on this stack, not that task's.
      sched_foreign_teardown[Gs->num]=task;
      task=TaskEnd();
      sched_foreign_teardown[Gs->num]=NULL;
      goto restore;
    }
    if(LBtr(&SYS_CTRL_ALT_FLAGS,CTRL_ALT_C)) {
      if(!sys_focus_task) {
        goto restore;
      }
      task=sys_focus_task;
      if(Bt(&task->win_inhibit,WIf_SELF_FOCUS)) {
        goto restore;
      }
      if(Bt(&task->task_flags,TASKf_BREAK_LOCKED)) {
        LBts(&task->task_flags,TASKf_PENDING_BREAK);
        goto restore;
      }
      TaskContextSetRIP(task->context_save_area,&Break);
      if(Bt(&task->task_flags,TASKf_BREAK_TO_SHIFT_ESC)) {
        goto restore;
      }
      goto restore;
    }
  }
not_seth:
next:
  task=task->next_task;
  if(task==Gs->seth_task)
    goto restore;
  if(Bt(&task->task_flags,TASKf_KILL_TASK)) {
    SetFs(task);
//TaskEnd() runs on this task's stack with Fs set to the dying one, so a Yield
//in there must not record a context pointing into our stack.
    sched_foreign_teardown[Gs->num]=task;
    task=TaskEnd();
    sched_foreign_teardown[Gs->num]=NULL;
    goto next;
  }
  if(task->wake_jiffy>__GetTicks) {
    goto next;
  }

  if(!(task->task_flags&(1<<TASKf_AWAITING_MSG|1<<TASKf_SUSPENDED))) {
    goto restore;
  } else
    goto next;
restore:
  SetFs(task);
  TaskContextRestore(task);
}

U0 TaskQueIns(CTask *task,CTask *pred=NULL)
{//Insert a task in the scheduler running task queue.
//You have no business with this, probably.
  CTask *last;
  Bool bl=BreakLock;
  if (!pred) pred=Fs;
  last=pred->last_task;
  last->next_task=pred->last_task=task;
  task->last_task=last;
  task->next_task=pred;
  if(bl)
    BreakUnlock;
}

U0 TaskQueRem(CTask *task)
{//Remove a task from the scheduler running task queue.
//Use $LK,"Suspend",A="MN:Suspend"$().
  CTask *next,*last;
  Bool bl=BreakLock;
  next=task->next_task;
  last=task->last_task;
  last->next_task=next;
  next->last_task=last;
  if(bl)
    BreakUnlock;
}

U0 TaskQueInsChild(CTask *task)
{
  CTask *last,*pred;
  Bool bl=BreakLock;
  pred=task->parent_task->last_child_task;
  last=pred->last_sibling_task;
  last->next_sibling_task=pred->last_sibling_task=task;
  task->last_sibling_task=last;
  task->next_sibling_task=pred;
  if(bl)
    BreakLock;
}
