/*! `monkey` grammar compiled for Highlight.js 11.6.0 */
(()=>{var e=(()=>{"use strict";return e=>{const n={className:"number",
relevance:0,variants:[{begin:"[$][a-fA-F0-9]+"},e.NUMBER_MODE]},a={variants:[{
match:[/(function|method)/,/\s+/,e.UNDERSCORE_IDENT_RE]}],scope:{1:"keyword",
3:"title.function"}},t={variants:[{
match:[/(class|interface|extends|implements)/,/\s+/,e.UNDERSCORE_IDENT_RE]}],
scope:{1:"keyword",3:"title.class"}};return{name:"Monkey",case_insensitive:!0,
keywords:{
keyword:["public","private","property","continue","exit","extern","new","try","catch","eachin","not","abstract","final","select","case","default","const","local","global","field","end","if","then","else","elseif","endif","while","wend","repeat","until","forever","for","to","step","next","return","module","inline","throw","import","and","or","shl","shr","mod"],
built_in:["DebugLog","DebugStop","Error","Print","ACos","ACosr","ASin","ASinr","ATan","ATan2","ATan2r","ATanr","Abs","Abs","Ceil","Clamp","Clamp","Cos","Cosr","Exp","Floor","Log","Max","Max","Min","Min","Pow","Sgn","Sgn","Sin","Sinr","Sqrt","Tan","Tanr","Seed","PI","HALFPI","TWOPI"],
literal:["true","false","null"]},illegal:/\/\*/,
contains:[e.COMMENT("#rem","#end"),e.COMMENT("'","$",{relevance:0}),a,t,{
className:"variable.language",begin:/\b(self|super)\b/},{className:"meta",
begin:/\s*#/,end:"$",keywords:{keyword:"if else elseif endif end then"}},{
match:[/^\s*/,/strict\b/],scope:{2:"meta"}},{beginKeywords:"alias",end:"=",
contains:[e.UNDERSCORE_TITLE_MODE]},e.QUOTE_STRING_MODE,n]}}})()
;hljs.registerLanguage("monkey",e)})();