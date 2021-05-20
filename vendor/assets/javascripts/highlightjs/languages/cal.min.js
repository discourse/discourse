hljs.registerLanguage("cal",(()=>{"use strict";return e=>{
const n="div mod in and or not xor asserterror begin case do downto else end exit for if of repeat then to until while with var",a=[e.C_LINE_COMMENT_MODE,e.COMMENT(/\{/,/\}/,{
relevance:0}),e.COMMENT(/\(\*/,/\*\)/,{relevance:10})],r={className:"string",
begin:/'/,end:/'/,contains:[{begin:/''/}]},s={className:"string",begin:/(#\d+)+/
},i={className:"function",beginKeywords:"procedure",end:/[:;]/,
keywords:"procedure|10",contains:[e.TITLE_MODE,{className:"params",begin:/\(/,
end:/\)/,keywords:n,contains:[r,s]}].concat(a)},t={className:"class",
begin:"OBJECT (Table|Form|Report|Dataport|Codeunit|XMLport|MenuSuite|Page|Query) (\\d+) ([^\\r\\n]+)",
returnBegin:!0,contains:[e.TITLE_MODE,i]};return{name:"C/AL",
case_insensitive:!0,keywords:{keyword:n,literal:"false true"},illegal:/\/\*/,
contains:[r,s,{className:"number",begin:"\\b\\d+(\\.\\d+)?(DT|D|T)",relevance:0
},{className:"string",begin:'"',end:'"'},e.NUMBER_MODE,t,i]}}})());