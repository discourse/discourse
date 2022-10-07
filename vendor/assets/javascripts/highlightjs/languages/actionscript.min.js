/*! `actionscript` grammar compiled for Highlight.js 11.6.0 */
(()=>{var e=(()=>{"use strict";return e=>{
const a=e.regex,t=/[a-zA-Z_$][a-zA-Z0-9_$]*/,n=a.concat(t,a.concat("(\\.",t,")*")),s={
className:"rest_arg",begin:/[.]{3}/,end:t,relevance:10};return{
name:"ActionScript",aliases:["as"],keywords:{
keyword:["as","break","case","catch","class","const","continue","default","delete","do","dynamic","each","else","extends","final","finally","for","function","get","if","implements","import","in","include","instanceof","interface","internal","is","namespace","native","new","override","package","private","protected","public","return","set","static","super","switch","this","throw","try","typeof","use","var","void","while","with"],
literal:["true","false","null","undefined"]},
contains:[e.APOS_STRING_MODE,e.QUOTE_STRING_MODE,e.C_LINE_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE,e.C_NUMBER_MODE,{
match:[/\bpackage/,/\s+/,n],className:{1:"keyword",3:"title.class"}},{
match:[/\b(?:class|interface|extends|implements)/,/\s+/,t],className:{
1:"keyword",3:"title.class"}},{className:"meta",beginKeywords:"import include",
end:/;/,keywords:{keyword:"import include"}},{beginKeywords:"function",
end:/[{;]/,excludeEnd:!0,illegal:/\S/,contains:[e.inherit(e.TITLE_MODE,{
className:"title.function"}),{className:"params",begin:/\(/,end:/\)/,
contains:[e.APOS_STRING_MODE,e.QUOTE_STRING_MODE,e.C_LINE_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE,s]
},{begin:a.concat(/:\s*/,/([*]|[a-zA-Z_$][a-zA-Z0-9_$]*)/)}]},e.METHOD_GUARD],
illegal:/#/}}})();hljs.registerLanguage("actionscript",e)})();