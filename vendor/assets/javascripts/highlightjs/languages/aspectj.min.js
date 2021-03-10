hljs.registerLanguage("aspectj",(()=>{"use strict";function e(...e){
return e.map((e=>{return(n=e)?"string"==typeof n?n:n.source:null;var n
})).join("")}return n=>{
const t="false synchronized int abstract float private char boolean static null if const for true while long throw strictfp finally protected import native final return void enum else extends implements break transient new catch instanceof byte super volatile case assert short package default double public try this switch continue throws privileged aspectOf adviceexecution proceed cflowbelow cflow initialization preinitialization staticinitialization withincode target within execution getWithinTypeName handler thisJoinPoint thisJoinPointStaticPart thisEnclosingJoinPointStaticPart declare parents warning error soft precedence thisAspectInstance",i="get set args call"
;return{name:"AspectJ",keywords:t,illegal:/<\/|#/,
contains:[n.COMMENT(/\/\*\*/,/\*\//,{relevance:0,contains:[{begin:/\w+@/,
relevance:0},{className:"doctag",begin:/@[A-Za-z]+/}]
}),n.C_LINE_COMMENT_MODE,n.C_BLOCK_COMMENT_MODE,n.APOS_STRING_MODE,n.QUOTE_STRING_MODE,{
className:"class",beginKeywords:"aspect",end:/[{;=]/,excludeEnd:!0,
illegal:/[:;"\[\]]/,contains:[{
beginKeywords:"extends implements pertypewithin perthis pertarget percflowbelow percflow issingleton"
},n.UNDERSCORE_TITLE_MODE,{begin:/\([^\)]*/,end:/[)]+/,keywords:t+" "+i,
excludeEnd:!1}]},{className:"class",beginKeywords:"class interface",end:/[{;=]/,
excludeEnd:!0,relevance:0,keywords:"class interface",illegal:/[:"\[\]]/,
contains:[{beginKeywords:"extends implements"},n.UNDERSCORE_TITLE_MODE]},{
beginKeywords:"pointcut after before around throwing returning",end:/[)]/,
excludeEnd:!1,illegal:/["\[\]]/,contains:[{
begin:e(n.UNDERSCORE_IDENT_RE,/\s*\(/),returnBegin:!0,
contains:[n.UNDERSCORE_TITLE_MODE]}]},{begin:/[:]/,returnBegin:!0,end:/[{;]/,
relevance:0,excludeEnd:!1,keywords:t,illegal:/["\[\]]/,contains:[{
begin:e(n.UNDERSCORE_IDENT_RE,/\s*\(/),keywords:t+" "+i,relevance:0
},n.QUOTE_STRING_MODE]},{beginKeywords:"new throw",relevance:0},{
className:"function",
begin:/\w+ +\w+(\.\w+)?\s*\([^\)]*\)\s*((throws)[\w\s,]+)?[\{;]/,returnBegin:!0,
end:/[{;=]/,keywords:t,excludeEnd:!0,contains:[{
begin:e(n.UNDERSCORE_IDENT_RE,/\s*\(/),returnBegin:!0,relevance:0,
contains:[n.UNDERSCORE_TITLE_MODE]},{className:"params",begin:/\(/,end:/\)/,
relevance:0,keywords:t,
contains:[n.APOS_STRING_MODE,n.QUOTE_STRING_MODE,n.C_NUMBER_MODE,n.C_BLOCK_COMMENT_MODE]
},n.C_LINE_COMMENT_MODE,n.C_BLOCK_COMMENT_MODE]},n.C_NUMBER_MODE,{
className:"meta",begin:/@[A-Za-z]+/}]}}})());