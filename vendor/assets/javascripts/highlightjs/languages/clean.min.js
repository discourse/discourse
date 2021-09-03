hljs.registerLanguage("clean",(()=>{"use strict";return e=>({name:"Clean",
aliases:["icl","dcl"],keywords:{
keyword:["if","let","in","with","where","case","of","class","instance","otherwise","implementation","definition","system","module","from","import","qualified","as","special","code","inline","foreign","export","ccall","stdcall","generic","derive","infix","infixl","infixr"],
built_in:"Int Real Char Bool",literal:"True False"},
contains:[e.C_LINE_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE,e.APOS_STRING_MODE,e.QUOTE_STRING_MODE,e.C_NUMBER_MODE,{
begin:"->|<-[|:]?|#!?|>>=|\\{\\||\\|\\}|:==|=:|<>"}]})})());