hljs.registerLanguage("actionscript",(()=>{"use strict";function e(...e){
return e.map((e=>{return(a=e)?"string"==typeof a?a:a.source:null;var a
})).join("")}return a=>{
const n=/[a-zA-Z_$][a-zA-Z0-9_$]*/,t=e(n,e("(\\.",n,")*")),s={
className:"rest_arg",begin:/[.]{3}/,end:n,relevance:10};return{
name:"ActionScript",aliases:["as"],keywords:{
keyword:["as","break","case","catch","class","const","continue","default","delete","do","dynamic","each","else","extends","final","finally","for","function","get","if","implements","import","in","include","instanceof","interface","internal","is","namespace","native","new","override","package","private","protected","public","return","set","static","super","switch","this","throw","try","typeof","use","var","void","while","with"],
literal:["true","false","null","undefined"]},
contains:[a.APOS_STRING_MODE,a.QUOTE_STRING_MODE,a.C_LINE_COMMENT_MODE,a.C_BLOCK_COMMENT_MODE,a.C_NUMBER_MODE,{
match:[/\bpackage/,/\s+/,t],className:{1:"keyword",3:"title.class"}},{
match:[/\b(?:class|interface|extends|implements)/,/\s+/,n],className:{
1:"keyword",3:"title.class"}},{className:"meta",beginKeywords:"import include",
end:/;/,keywords:{keyword:"import include"}},{beginKeywords:"function",
end:/[{;]/,excludeEnd:!0,illegal:/\S/,contains:[a.inherit(a.TITLE_MODE,{
className:"title.function"}),{className:"params",begin:/\(/,end:/\)/,
contains:[a.APOS_STRING_MODE,a.QUOTE_STRING_MODE,a.C_LINE_COMMENT_MODE,a.C_BLOCK_COMMENT_MODE,s]
},{begin:e(/:\s*/,/([*]|[a-zA-Z_$][a-zA-Z0-9_$]*)/)}]},a.METHOD_GUARD],
illegal:/#/}}})());