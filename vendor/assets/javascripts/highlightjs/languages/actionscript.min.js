hljs.registerLanguage("actionscript",(()=>{"use strict";function e(...e){
return e.map((e=>{return(n=e)?"string"==typeof n?n:n.source:null;var n
})).join("")}return n=>({name:"ActionScript",aliases:["as"],keywords:{
keyword:"as break case catch class const continue default delete do dynamic each else extends final finally for function get if implements import in include instanceof interface internal is namespace native new override package private protected public return set static super switch this throw try typeof use var void while with",
literal:"true false null undefined"},
contains:[n.APOS_STRING_MODE,n.QUOTE_STRING_MODE,n.C_LINE_COMMENT_MODE,n.C_BLOCK_COMMENT_MODE,n.C_NUMBER_MODE,{
className:"class",beginKeywords:"package",end:/\{/,contains:[n.TITLE_MODE]},{
className:"class",beginKeywords:"class interface",end:/\{/,excludeEnd:!0,
contains:[{beginKeywords:"extends implements"},n.TITLE_MODE]},{className:"meta",
beginKeywords:"import include",end:/;/,keywords:{"meta-keyword":"import include"
}},{className:"function",beginKeywords:"function",end:/[{;]/,excludeEnd:!0,
illegal:/\S/,contains:[n.TITLE_MODE,{className:"params",begin:/\(/,end:/\)/,
contains:[n.APOS_STRING_MODE,n.QUOTE_STRING_MODE,n.C_LINE_COMMENT_MODE,n.C_BLOCK_COMMENT_MODE,{
className:"rest_arg",begin:/[.]{3}/,end:/[a-zA-Z_$][a-zA-Z0-9_$]*/,relevance:10
}]},{begin:e(/:\s*/,/([*]|[a-zA-Z_$][a-zA-Z0-9_$]*)/)}]},n.METHOD_GUARD],
illegal:/#/})})());