hljs.registerLanguage("wren",(()=>{"use strict";function e(e){
return e?"string"==typeof e?e:e.source:null}function s(...s){
return s.map((s=>e(s))).join("")}function a(...s){return"("+((e=>{
const s=e[e.length-1]
;return"object"==typeof s&&s.constructor===Object?(e.splice(e.length-1,1),s):{}
})(s).capture?"":"?:")+s.map((s=>e(s))).join("|")+")"}return e=>{
const n=/[a-zA-Z]\w*/,t=["as","break","class","construct","continue","else","for","foreign","if","import","in","is","return","static","var","while"],c=["true","false","null"],r=["this","super"],i=["-","~",/\*/,"%",/\.\.\./,/\.\./,/\+/,"<<",">>",">=","<=","<",">",/\^/,/!=/,/!/,/\bis\b/,"==","&&","&",/\|\|/,/\|/,/\?:/,"="],o={
relevance:0,match:s(/\b(?!(if|while|for|else|super)\b)/,n,/(?=\s*[({])/),
className:"title.function"},l={
match:s(a(s(/\b(?!(if|while|for|else|super)\b)/,n),a(...i)),/(?=\s*\([^)]+\)\s*\{)/),
className:"title.function",starts:{contains:[{begin:/\(/,end:/\)/,contains:[{
relevance:0,scope:"params",match:n}]}]}},u={variants:[{
match:[/class\s+/,n,/\s+is\s+/,n]},{match:[/class\s+/,n]}],scope:{
2:"title.class",4:"title.class.inherited"},keywords:t},m={relevance:0,
match:a(...i),className:"operator"},p={className:"property",
begin:s(/\./,(b=n,s("(?=",b,")"))),end:n,excludeBegin:!0,relevance:0};var b
;const h={relevance:0,match:s(/\b_/,n),scope:"variable"},g={relevance:0,
match:/\b[A-Z]+[a-z]+([A-Z]+[a-z]+)*/,scope:"title.class",keywords:{
_:["Bool","Class","Fiber","Fn","List","Map","Null","Num","Object","Range","Sequence","String","System"]
}},f=e.C_NUMBER_MODE,v={match:[n,/\s*/,/=/,/\s*/,/\(/,n,/\)\s*\{/],scope:{
1:"title.function",3:"operator",6:"params"}},d=e.COMMENT(/\/\*\*/,/\*\//,{
contains:[{match:/@[a-z]+/,scope:"doctag"},"self"]}),N={scope:"subst",
begin:/%\(/,end:/\)/,contains:[f,g,o,h,m]},_={scope:"string",begin:/"/,end:/"/,
contains:[N,{scope:"char.escape",variants:[{match:/\\\\|\\["0%abefnrtv]/},{
match:/\\x[0-9A-F]{2}/},{match:/\\u[0-9A-F]{4}/},{match:/\\U[0-9A-F]{8}/}]}]}
;N.contains.push(_);const w={relevance:0,
match:s("\\b(?!",[...t,...r,...c].join("|"),"\\b)",/[a-zA-Z_]\w*(?:[?!]|\b)/),
className:"variable"};return{name:"Wren",keywords:{keyword:t,
"variable.language":r,literal:c},contains:[{scope:"comment",variants:[{
begin:[/#!?/,/[A-Za-z_]+(?=\()/],beginScope:{},keywords:{literal:c},contains:[],
end:/\)/},{begin:[/#!?/,/[A-Za-z_]+/],beginScope:{},end:/$/}]},f,_,{
className:"string",begin:/"""/,end:/"""/
},d,e.C_LINE_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE,g,u,v,l,o,m,h,p,w]}}})());