/*! `cal` grammar compiled for Highlight.js 11.6.0 */
(()=>{var e=(()=>{"use strict";return e=>{
const n=e.regex,a=["div","mod","in","and","or","not","xor","asserterror","begin","case","do","downto","else","end","exit","for","local","if","of","repeat","then","to","until","while","with","var"],r=[e.C_LINE_COMMENT_MODE,e.COMMENT(/\{/,/\}/,{
relevance:0}),e.COMMENT(/\(\*/,/\*\)/,{relevance:10})],t={className:"string",
begin:/'/,end:/'/,contains:[{begin:/''/}]},s={className:"string",begin:/(#\d+)+/
},i={match:[/procedure/,/\s+/,/[a-zA-Z_][\w@]*/,/\s*/],scope:{1:"keyword",
3:"title.function"},contains:[{className:"params",begin:/\(/,end:/\)/,
keywords:a,contains:[t,s,e.NUMBER_MODE]},...r]},o={
match:[/OBJECT/,/\s+/,n.either("Table","Form","Report","Dataport","Codeunit","XMLport","MenuSuite","Page","Query"),/\s+/,/\d+/,/\s+(?=[^\s])/,/.*/,/$/],
relevance:3,scope:{1:"keyword",3:"type",5:"number",7:"title"}};return{
name:"C/AL",case_insensitive:!0,keywords:{keyword:a,literal:"false true"},
illegal:/\/\*/,contains:[{match:/[\w]+(?=\=)/,scope:"attribute",relevance:0
},t,s,{className:"number",begin:"\\b\\d+(\\.\\d+)?(DT|D|T)",relevance:0},{
className:"string",begin:'"',end:'"'},e.NUMBER_MODE,o,i]}}})()
;hljs.registerLanguage("cal",e)})();