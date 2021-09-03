hljs.registerLanguage("nginx",(()=>{"use strict";function e(e){
return n("(?=",e,")")}function n(...e){return e.map((e=>{
return(n=e)?"string"==typeof n?n:n.source:null;var n})).join("")}return a=>{
const s={className:"variable",variants:[{begin:/\$\d+/},{begin:/\$\{\w+\}/},{
begin:n(/[$@]/,a.UNDERSCORE_IDENT_RE)}]},i={endsWithParent:!0,keywords:{
$pattern:/[a-z_]{2,}|\/dev\/poll/,
literal:["on","off","yes","no","true","false","none","blocked","debug","info","notice","warn","error","crit","select","break","last","permanent","redirect","kqueue","rtsig","epoll","poll","/dev/poll"]
},relevance:0,illegal:"=>",contains:[a.HASH_COMMENT_MODE,{className:"string",
contains:[a.BACKSLASH_ESCAPE,s],variants:[{begin:/"/,end:/"/},{begin:/'/,end:/'/
}]},{begin:"([a-z]+):/",end:"\\s",endsWithParent:!0,excludeEnd:!0,contains:[s]
},{className:"regexp",contains:[a.BACKSLASH_ESCAPE,s],variants:[{begin:"\\s\\^",
end:"\\s|\\{|;",returnEnd:!0},{begin:"~\\*?\\s+",end:"\\s|\\{|;",returnEnd:!0},{
begin:"\\*(\\.[a-z\\-]+)+"},{begin:"([a-z\\-]+\\.)+\\*"}]},{className:"number",
begin:"\\b\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}(:\\d{1,5})?\\b"},{
className:"number",begin:"\\b\\d+[kKmMgGdshdwy]?\\b",relevance:0},s]};return{
name:"Nginx config",aliases:["nginxconf"],contains:[a.HASH_COMMENT_MODE,{
beginKeywords:"upstream location",end:/;|\{/,contains:i.contains,keywords:{
section:"upstream location"}},{className:"section",
begin:n(a.UNDERSCORE_IDENT_RE+e(/\s+\{/)),relevance:0},{
begin:e(a.UNDERSCORE_IDENT_RE+"\\s"),end:";|\\{",contains:[{
className:"attribute",begin:a.UNDERSCORE_IDENT_RE,starts:i}],relevance:0}],
illegal:"[^\\s\\}\\{]"}}})());