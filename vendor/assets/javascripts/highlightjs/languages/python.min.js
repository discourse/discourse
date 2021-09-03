hljs.registerLanguage("python",(()=>{"use strict";function e(e){
return e?"string"==typeof e?e:e.source:null}function n(...n){
return n.map((n=>e(n))).join("")}const t="[a-zA-Z_]\\w*",a=(t,a,s={})=>{
const i=((e,...n)=>{const t=Object.create(null);for(const n in e)t[n]=e[n]
;return n.forEach((e=>{for(const n in e)t[n]=e[n]})),t})({scope:"comment",
begin:t,end:a,contains:[]},s);i.contains.push({scope:"doctag",
begin:"[ ]*(?=(TODO|FIXME|NOTE|BUG|OPTIMIZE|HACK|XXX):)",
end:/(TODO|FIXME|NOTE|BUG|OPTIMIZE|HACK|XXX):/,excludeBegin:!0,relevance:0})
;const r=function(...n){return"("+((e=>{const n=e[e.length-1]
;return"object"==typeof n&&n.constructor===Object?(e.splice(e.length-1,1),n):{}
})(n).capture?"":"?:")+n.map((n=>e(n))).join("|")+")"
}("I","a","is","so","us","to","at","if","in","it","on",/[A-Za-z]+['](d|ve|re|ll|t|s|n)/,/[A-Za-z]+[-][a-z]+/,/[A-Za-z][a-z]{2,}/)
;return i.contains.push({begin:n(/[ ]+/,"(",r,/[.]?[:]?([.][ ]|[ ])/,"){3}")}),i
};return a("//","$"),a("/\\*","\\*/"),a("#","$"),e=>{const a={
$pattern:/[A-Za-z]\w+|__\w+__/,
keyword:["and","as","assert","async","await","break","class","continue","def","del","elif","else","except","finally","for","from","global","if","import","in","is","lambda","nonlocal|10","not","or","pass","raise","return","try","while","with","yield"],
built_in:["__import__","abs","all","any","ascii","bin","bool","breakpoint","bytearray","bytes","callable","chr","classmethod","compile","complex","delattr","dict","dir","divmod","enumerate","eval","exec","filter","float","format","frozenset","getattr","globals","hasattr","hash","help","hex","id","input","int","isinstance","issubclass","iter","len","list","locals","map","max","memoryview","min","next","object","oct","open","ord","pow","print","property","range","repr","reversed","round","set","setattr","slice","sorted","staticmethod","str","sum","super","tuple","type","vars","zip"],
literal:["__debug__","Ellipsis","False","None","NotImplemented","True"],
type:["Any","Callable","Coroutine","Dict","List","Literal","Generic","Optional","Sequence","Set","Tuple","Type","Union"]
},s={className:"meta",begin:/^(>>>|\.\.\.) /},i={className:"subst",begin:/\{/,
end:/\}/,keywords:a,illegal:/#/},r={begin:/\{\{/,relevance:0},o={
className:"string",contains:[e.BACKSLASH_ESCAPE],variants:[{
begin:/([uU]|[bB]|[rR]|[bB][rR]|[rR][bB])?'''/,end:/'''/,
contains:[e.BACKSLASH_ESCAPE,s],relevance:10},{
begin:/([uU]|[bB]|[rR]|[bB][rR]|[rR][bB])?"""/,end:/"""/,
contains:[e.BACKSLASH_ESCAPE,s],relevance:10},{
begin:/([fF][rR]|[rR][fF]|[fF])'''/,end:/'''/,
contains:[e.BACKSLASH_ESCAPE,s,r,i]},{begin:/([fF][rR]|[rR][fF]|[fF])"""/,
end:/"""/,contains:[e.BACKSLASH_ESCAPE,s,r,i]},{begin:/([uU]|[rR])'/,end:/'/,
relevance:10},{begin:/([uU]|[rR])"/,end:/"/,relevance:10},{
begin:/([bB]|[bB][rR]|[rR][bB])'/,end:/'/},{begin:/([bB]|[bB][rR]|[rR][bB])"/,
end:/"/},{begin:/([fF][rR]|[rR][fF]|[fF])'/,end:/'/,
contains:[e.BACKSLASH_ESCAPE,r,i]},{begin:/([fF][rR]|[rR][fF]|[fF])"/,end:/"/,
contains:[e.BACKSLASH_ESCAPE,r,i]},e.APOS_STRING_MODE,e.QUOTE_STRING_MODE]
},l="[0-9](_?[0-9])*",c=`(\\b(${l}))?\\.(${l})|\\b(${l})\\.`,b={
className:"number",relevance:0,variants:[{
begin:`(\\b(${l})|(${c}))[eE][+-]?(${l})[jJ]?\\b`},{begin:`(${c})[jJ]?`},{
begin:"\\b([1-9](_?[0-9])*|0+(_?0)*)[lLjJ]?\\b"},{
begin:"\\b0[bB](_?[01])+[lL]?\\b"},{begin:"\\b0[oO](_?[0-7])+[lL]?\\b"},{
begin:"\\b0[xX](_?[0-9a-fA-F])+[lL]?\\b"},{begin:`\\b(${l})[jJ]\\b`}]},d={
className:"comment",begin:(g=/# type:/,n("(?=",g,")")),end:/$/,keywords:a,
contains:[{begin:/# type:/},{begin:/#/,end:/\b\B/,endsWithParent:!0}]};var g
;const p={className:"params",variants:[{className:"",begin:/\(\s*\)/,skip:!0},{
begin:/\(/,end:/\)/,excludeBegin:!0,excludeEnd:!0,keywords:a,
contains:["self",s,b,o,e.HASH_COMMENT_MODE]}]};return i.contains=[o,b,s],{
name:"Python",aliases:["py","gyp","ipython"],keywords:a,
illegal:/(<\/|->|\?)|=>/,contains:[s,b,{begin:/\bself\b/},{beginKeywords:"if",
relevance:0},o,d,e.HASH_COMMENT_MODE,{match:[/def/,/\s+/,t],scope:{1:"keyword",
3:"title.function"},contains:[p]},{variants:[{
match:[/class/,/\s+/,t,/\s*/,/\(\s*/,t,/\s*\)/]},{match:[/class/,/\s+/,t]}],
scope:{1:"keyword",3:"title.class",6:"title.class.inherited"}},{
className:"meta",begin:/^[\t ]*@/,end:/(?=#)|$/,contains:[b,p,o]}]}}})());