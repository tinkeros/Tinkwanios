//Asm-callable entry points for the print routines, the ones TempleOS and
//TinkerOS export from Kernel/StrA.HC.  Asm written for TempleOS calls these
//by name, so without them a CALL PUT_STR resolves to 0 and jumps to address
//zero -- see ::/Demo/Asm/AsmHelloWorld.HC.
//
//Conventions are TinkerOS's, unchanged: the number or char arrives in RAX,
//a string pointer in RSI, and every register is preserved.  Lives in its own
//file because Src/StrA.HC is #included twice by FULL_PACKAGE.HC and an asm
//label may only be defined once.
//TinkerOS's versions call PutS and PutChars straight out of the asm.  That
//does not carry over: PutS here only feeds the key-device chain, so nothing
//reaches the screen on the desktop, and PutChars produces nothing under -c
//(it goes through PutKey, and unlike PutS it has no IsCmdLineMode path).
//Each entry point would then work in one mode and not the other.  Printing
//is the entire job of these routines, so go through the ordinary print path
//instead; PutHex already does.
U0 PutStrAsm(U8 *st)
{
  if (st)
    "%s",st;
}

U0 PutCharsAsm(U64 c)
{//Up to 8 chars packed in the one reg, as the char-const form gives.
  "%c",c;
}

asm
{
//IN: RAX=num to print
  PUT_HEX_U64::
  PUSH_C_REGS
  PUSH	16
  PUSH	RAX
  CALL	&PutHex
  POP_C_REGS
  RET

  PUT_HEX_U32::
  PUSH_C_REGS
  PUSH	8
  PUSH	RAX
  CALL	&PutHex
  POP_C_REGS
  RET

  PUT_HEX_U16::
  PUSH_C_REGS
  PUSH	4
  PUSH	RAX
  CALL	&PutHex
  POP_C_REGS
  RET

  PUT_HEX_U8::
  PUSH_C_REGS
  PUSH	2
  PUSH	RAX
  CALL	&PutHex
  POP_C_REGS
  RET

//IN: RAX=char, or several packed into the one reg
  PUT_CHARS::
  PUSH_C_REGS
  PUSH	RAX
  CALL	&PutCharsAsm
  POP_C_REGS
  RET

//IN: RSI=string
  PUT_STR::
  PUSH_C_REGS
  PUSH	RSI
  CALL	&PutStrAsm
  POP_C_REGS
  RET
};
