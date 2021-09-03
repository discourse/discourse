hljs.registerLanguage("diff",(()=>{"use strict";function e(...e){
return"("+((e=>{const n=e[e.length-1]
;return"object"==typeof n&&n.constructor===Object?(e.splice(e.length-1,1),n):{}
})(e).capture?"":"?:")+e.map((e=>{return(n=e)?"string"==typeof n?n:n.source:null
;var n})).join("|")+")"}return n=>({name:"Diff",aliases:["patch"],contains:[{
className:"meta",relevance:10,
match:e(/^@@ +-\d+,\d+ +\+\d+,\d+ +@@/,/^\*\*\* +\d+,\d+ +\*\*\*\*$/,/^--- +\d+,\d+ +----$/)
},{className:"comment",variants:[{
begin:e(/Index: /,/^index/,/={3,}/,/^-{3}/,/^\*{3} /,/^\+{3}/,/^diff --git/),
end:/$/},{match:/^\*{15}$/}]},{className:"addition",begin:/^\+/,end:/$/},{
className:"deletion",begin:/^-/,end:/$/},{className:"addition",begin:/^!/,
end:/$/}]})})());