hljs.registerLanguage("elixir",(()=>{"use strict";function e(...e){
return e.map((e=>{return(n=e)?"string"==typeof n?n:n.source:null;var n
})).join("")}return n=>{const i="[a-zA-Z_][a-zA-Z0-9_.]*(!|\\?)?",a={$pattern:i,
keyword:["after","alias","and","case","catch","cond","defstruct","do","else","end","fn","for","if","import","in","not","or","quote","raise","receive","require","reraise","rescue","try","unless","unquote","unquote_splicing","use","when","with|0"],
literal:["false","nil","true"]},s={className:"subst",begin:/#\{/,end:/\}/,
keywords:a},r={match:/\\[\s\S]/,scope:"char.escape",relevance:0},t=[{begin:/"/,
end:/"/},{begin:/'/,end:/'/},{begin:/\//,end:/\//},{begin:/\|/,end:/\|/},{
begin:/\(/,end:/\)/},{begin:/\[/,end:/\]/},{begin:/\{/,end:/\}/},{begin:/</,
end:/>/}],c=n=>({scope:"char.escape",begin:e(/\\/,n),relevance:0}),o={
className:"string",begin:"~[a-z](?=[/|([{<\"'])",
contains:t.map((e=>n.inherit(e,{contains:[c(e.end),r,s]})))},d={
className:"string",begin:"~[A-Z](?=[/|([{<\"'])",
contains:t.map((e=>n.inherit(e,{contains:[c(e.end)]})))},b={className:"regex",
variants:[{begin:"~r(?=[/|([{<\"'])",contains:t.map((i=>n.inherit(i,{
end:e(i.end,/[uismxfU]{0,7}/),contains:[c(i.end),r,s]})))},{
begin:"~R(?=[/|([{<\"'])",contains:t.map((i=>n.inherit(i,{
end:e(i.end,/[uismxfU]{0,7}/),contains:[c(i.end)]})))}]},g={className:"string",
contains:[n.BACKSLASH_ESCAPE,s],variants:[{begin:/"""/,end:/"""/},{begin:/'''/,
end:/'''/},{begin:/~S"""/,end:/"""/,contains:[]},{begin:/~S"/,end:/"/,
contains:[]},{begin:/~S'''/,end:/'''/,contains:[]},{begin:/~S'/,end:/'/,
contains:[]},{begin:/'/,end:/'/},{begin:/"/,end:/"/}]},l={className:"function",
beginKeywords:"def defp defmacro defmacrop",end:/\B\b/,
contains:[n.inherit(n.TITLE_MODE,{begin:i,endsParent:!0})]},m=n.inherit(l,{
className:"class",beginKeywords:"defimpl defmodule defprotocol defrecord",
end:/\bdo\b|$|;/}),u=[g,b,d,o,n.HASH_COMMENT_MODE,m,l,{begin:"::"},{
className:"symbol",begin:":(?![\\s:])",contains:[g,{
begin:"[a-zA-Z_]\\w*[!?=]?|[-+~]@|<<|>>|=~|===?|<=>|[<>]=?|\\*\\*|[-/+%^&*~`|]|\\[\\]=?"
}],relevance:0},{className:"symbol",begin:i+":(?!:)",relevance:0},{
className:"number",
begin:"(\\b0o[0-7_]+)|(\\b0b[01_]+)|(\\b0x[0-9a-fA-F_]+)|(-?\\b[0-9][0-9_]*(\\.[0-9_]+([eE][-+]?[0-9]+)?)?)",
relevance:0},{className:"variable",begin:"(\\$\\W)|((\\$|@@?)(\\w+))"},{
begin:"->"}];return s.contains=u,{name:"Elixir",aliases:["ex","exs"],keywords:a,
contains:u}}})());