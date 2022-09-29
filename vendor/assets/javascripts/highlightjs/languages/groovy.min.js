/*! `groovy` grammar compiled for Highlight.js 11.6.0 */
(()=>{var e=(()=>{"use strict";function e(e,a={}){return a.variants=e,a}
return a=>{
const n=a.regex,t="[A-Za-z0-9_$]+",r=e([a.C_LINE_COMMENT_MODE,a.C_BLOCK_COMMENT_MODE,a.COMMENT("/\\*\\*","\\*/",{
relevance:0,contains:[{begin:/\w+@/,relevance:0},{className:"doctag",
begin:"@[A-Za-z]+"}]})]),s={className:"regexp",begin:/~?\/[^\/\n]+\//,
contains:[a.BACKSLASH_ESCAPE]
},i=e([a.BINARY_NUMBER_MODE,a.C_NUMBER_MODE]),l=e([{begin:/"""/,end:/"""/},{
begin:/'''/,end:/'''/},{begin:"\\$/",end:"/\\$",relevance:10
},a.APOS_STRING_MODE,a.QUOTE_STRING_MODE],{className:"string"}),c={
match:[/(class|interface|trait|enum|extends|implements)/,/\s+/,a.UNDERSCORE_IDENT_RE],
scope:{1:"keyword",3:"title.class"}};return{name:"Groovy",keywords:{
"variable.language":"this super",literal:"true false null",
type:["byte","short","char","int","long","boolean","float","double","void"],
keyword:["def","as","in","assert","trait","abstract","static","volatile","transient","public","private","protected","synchronized","final","class","interface","enum","if","else","for","while","switch","case","break","default","continue","throw","throws","try","catch","finally","implements","extends","new","import","package","return","instanceof"]
},contains:[a.SHEBANG({binary:"groovy",relevance:10}),r,l,s,i,c,{
className:"meta",begin:"@[A-Za-z]+",relevance:0},{className:"attr",
begin:t+"[ \t]*:",relevance:0},{begin:/\?/,end:/:/,relevance:0,
contains:[r,l,s,i,"self"]},{className:"symbol",
begin:"^[ \t]*"+n.lookahead(t+":"),excludeBegin:!0,end:t+":",relevance:0}],
illegal:/#|<\//}}})();hljs.registerLanguage("groovy",e)})();