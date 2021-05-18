hljs.registerLanguage("gams",(()=>{"use strict";function e(...e){
return e.map((e=>{return(n=e)?"string"==typeof n?n:n.source:null;var n
})).join("")}return n=>{const a={
keyword:"abort acronym acronyms alias all and assign binary card diag display else eq file files for free ge gt if integer le loop lt maximizing minimizing model models ne negative no not option options or ord positive prod put putpage puttl repeat sameas semicont semiint smax smin solve sos1 sos2 sum system table then until using while xor yes",
literal:"eps inf na",
built_in:"abs arccos arcsin arctan arctan2 Beta betaReg binomial ceil centropy cos cosh cvPower div div0 eDist entropy errorf execSeed exp fact floor frac gamma gammaReg log logBeta logGamma log10 log2 mapVal max min mod ncpCM ncpF ncpVUpow ncpVUsin normal pi poly power randBinomial randLinear randTriangle round rPower sigmoid sign signPower sin sinh slexp sllog10 slrec sqexp sqlog10 sqr sqrec sqrt tan tanh trunc uniform uniformInt vcPower bool_and bool_eqv bool_imp bool_not bool_or bool_xor ifThen rel_eq rel_ge rel_gt rel_le rel_lt rel_ne gday gdow ghour gleap gmillisec gminute gmonth gsecond gyear jdate jnow jstart jtime errorLevel execError gamsRelease gamsVersion handleCollect handleDelete handleStatus handleSubmit heapFree heapLimit heapSize jobHandle jobKill jobStatus jobTerminate licenseLevel licenseStatus maxExecError sleep timeClose timeComp timeElapsed timeExec timeStart"
},i={className:"symbol",variants:[{begin:/=[lgenxc]=/},{begin:/\$/}]},s={
className:"comment",variants:[{begin:"'",end:"'"},{begin:'"',end:'"'}],
illegal:"\\n",contains:[n.BACKSLASH_ESCAPE]},o={begin:"/",end:"/",keywords:a,
contains:[s,n.C_LINE_COMMENT_MODE,n.C_BLOCK_COMMENT_MODE,n.QUOTE_STRING_MODE,n.APOS_STRING_MODE,n.C_NUMBER_MODE]
},t=/[a-z0-9&#*=?@\\><:,()$[\]_.{}!+%^-]+/,r={
begin:/[a-z][a-z0-9_]*(\([a-z0-9_, ]*\))?[ \t]+/,excludeBegin:!0,end:"$",
endsWithParent:!0,contains:[s,o,{className:"comment",
begin:e(t,(l=e(/[ ]+/,t),e("(",l,")*"))),relevance:0}]};var l;return{
name:"GAMS",aliases:["gms"],case_insensitive:!0,keywords:a,
contains:[n.COMMENT(/^\$ontext/,/^\$offtext/),{className:"meta",
begin:"^\\$[a-z0-9]+",end:"$",returnBegin:!0,contains:[{
className:"meta-keyword",begin:"^\\$[a-z0-9]+"}]
},n.COMMENT("^\\*","$"),n.C_LINE_COMMENT_MODE,n.C_BLOCK_COMMENT_MODE,n.QUOTE_STRING_MODE,n.APOS_STRING_MODE,{
beginKeywords:"set sets parameter parameters variable variables scalar scalars equation equations",
end:";",
contains:[n.COMMENT("^\\*","$"),n.C_LINE_COMMENT_MODE,n.C_BLOCK_COMMENT_MODE,n.QUOTE_STRING_MODE,n.APOS_STRING_MODE,o,r]
},{beginKeywords:"table",end:";",returnBegin:!0,contains:[{
beginKeywords:"table",end:"$",contains:[r]
},n.COMMENT("^\\*","$"),n.C_LINE_COMMENT_MODE,n.C_BLOCK_COMMENT_MODE,n.QUOTE_STRING_MODE,n.APOS_STRING_MODE,n.C_NUMBER_MODE]
},{className:"function",begin:/^[a-z][a-z0-9_,\-+' ()$]+\.{2}/,returnBegin:!0,
contains:[{className:"title",begin:/^[a-z0-9_]+/},{className:"params",
begin:/\(/,end:/\)/,excludeBegin:!0,excludeEnd:!0},i]},n.C_NUMBER_MODE,i]}}
})());