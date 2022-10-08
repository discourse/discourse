/*! `axapta` grammar compiled for Highlight.js 11.6.0 */
(()=>{var e=(()=>{"use strict";return e=>{const t=e.UNDERSCORE_IDENT_RE,s={
keyword:["abstract","as","asc","avg","break","breakpoint","by","byref","case","catch","changecompany","class","client","client","common","const","continue","count","crosscompany","delegate","delete_from","desc","display","div","do","edit","else","eventhandler","exists","extends","final","finally","firstfast","firstonly","firstonly1","firstonly10","firstonly100","firstonly1000","flush","for","forceliterals","forcenestedloop","forceplaceholders","forceselectorder","forupdate","from","generateonly","group","hint","if","implements","in","index","insert_recordset","interface","internal","is","join","like","maxof","minof","mod","namespace","new","next","nofetch","notexists","optimisticlock","order","outer","pessimisticlock","print","private","protected","public","readonly","repeatableread","retry","return","reverse","select","server","setting","static","sum","super","switch","this","throw","try","ttsabort","ttsbegin","ttscommit","unchecked","update_recordset","using","validtimestate","void","where","while"],
built_in:["anytype","boolean","byte","char","container","date","double","enum","guid","int","int64","long","real","short","str","utcdatetime","var"],
literal:["default","false","null","true"]},r={variants:[{
match:[/(class|interface)\s+/,t,/\s+(extends|implements)\s+/,t]},{
match:[/class\s+/,t]}],scope:{2:"title.class",4:"title.class.inherited"},
keywords:s};return{name:"X++",aliases:["x++"],keywords:s,
contains:[e.C_LINE_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE,e.APOS_STRING_MODE,e.QUOTE_STRING_MODE,e.C_NUMBER_MODE,{
className:"meta",begin:"#",end:"$"},r]}}})();hljs.registerLanguage("axapta",e)
})();