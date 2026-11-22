#help_index "Debugging/Dump"

// Poor Adam was severly dismembered in Aiwnios
// let's at least give him a put_doc so we can
// log to him.

adam_task->put_doc=DocNew;

public U0 DumpAdamLog()
{// Output Adam Log to current doc/term
    DocInsDoc(DocPut,adam_task->put_doc);
}

#help_index ""
