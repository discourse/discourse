hljs.registerLanguage("dts",(()=>{"use strict";return e=>{const n={
className:"string",variants:[e.inherit(e.QUOTE_STRING_MODE,{
begin:'((u8?|U)|L)?"'}),{begin:'(u8?|U)?R"',end:'"',
contains:[e.BACKSLASH_ESCAPE]},{begin:"'\\\\?.",end:"'",illegal:"."}]},a={
className:"number",variants:[{
begin:"\\b(\\d+(\\.\\d*)?|\\.\\d+)(u|U|l|L|ul|UL|f|F)"},{begin:e.C_NUMBER_RE}],
relevance:0},s={className:"meta",begin:"#",end:"$",keywords:{
"meta-keyword":"if else elif endif define undef ifdef ifndef"},contains:[{
begin:/\\\n/,relevance:0},{beginKeywords:"include",end:"$",keywords:{
"meta-keyword":"include"},contains:[e.inherit(n,{className:"meta-string"}),{
className:"meta-string",begin:"<",end:">",illegal:"\\n"}]
},n,e.C_LINE_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE]},i={className:"variable",
begin:/&[a-z\d_]*\b/},d={className:"meta-keyword",begin:"/[a-z][a-z\\d-]*/"},l={
className:"symbol",begin:"^\\s*[a-zA-Z_][a-zA-Z\\d_]*:"},r={className:"params",
begin:"<",end:">",contains:[a,i]},_={className:"class",
begin:/[a-zA-Z_][a-zA-Z\d_@]*\s\{/,end:/[{;=]/,returnBegin:!0,excludeEnd:!0}
;return{name:"Device Tree",keywords:"",contains:[{className:"class",
begin:"/\\s*\\{",end:/\};/,relevance:10,
contains:[i,d,l,_,r,e.C_LINE_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE,a,n]
},i,d,l,_,r,e.C_LINE_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE,a,n,s,{
begin:e.IDENT_RE+"::",keywords:""}]}}})());