hljs.registerLanguage("typescript",(()=>{"use strict"
;const e="[A-Za-z$_][0-9A-Za-z$_]*",n=["as","in","of","if","for","while","finally","var","new","function","do","return","void","else","break","catch","instanceof","with","throw","case","default","try","switch","continue","typeof","delete","let","yield","const","class","debugger","async","await","static","import","from","export","extends"],a=["true","false","null","undefined","NaN","Infinity"],t=["Intl","DataView","Number","Math","Date","String","RegExp","Object","Function","Boolean","Error","Symbol","Set","Map","WeakSet","WeakMap","Proxy","Reflect","JSON","Promise","Float64Array","Int16Array","Int32Array","Int8Array","Uint16Array","Uint32Array","Float32Array","Array","Uint8Array","Uint8ClampedArray","ArrayBuffer","BigInt64Array","BigUint64Array","BigInt"],s=["EvalError","InternalError","RangeError","ReferenceError","SyntaxError","TypeError","URIError"],r=["setInterval","setTimeout","clearInterval","clearTimeout","require","exports","eval","isFinite","isNaN","parseFloat","parseInt","decodeURI","decodeURIComponent","encodeURI","encodeURIComponent","escape","unescape"],c=["arguments","this","super","console","window","document","localStorage","module","global"],i=[].concat(r,t,s)
;function o(e){return l("(?=",e,")")}function l(...e){return e.map((e=>{
return(n=e)?"string"==typeof n?n:n.source:null;var n})).join("")}return b=>{
const d={$pattern:e,
keyword:n.concat(["type","namespace","typedef","interface","public","private","protected","implements","declare","abstract","readonly"]),
literal:a,
built_in:i.concat(["any","void","number","boolean","string","object","never","enum"]),
"variable.language":c},g={className:"meta",begin:"@[A-Za-z$_][0-9A-Za-z$_]*"
},u=(e,n,a)=>{const t=e.contains.findIndex((e=>e.label===n))
;if(-1===t)throw Error("can not find mode to replace");e.contains.splice(t,1,a)
},m=function(b){const d=e,g={begin:/<[A-Za-z0-9\\._:-]+/,
end:/\/[A-Za-z0-9\\._:-]+>|\/>/,isTrulyOpeningTag:(e,n)=>{
const a=e[0].length+e.index,t=e.input[a];"<"!==t?">"===t&&(((e,{after:n})=>{
const a="</"+e[0].slice(1);return-1!==e.input.indexOf(a,n)})(e,{after:a
})||n.ignoreMatch()):n.ignoreMatch()}},u={$pattern:e,keyword:n,literal:a,
built_in:i,"variable.language":c
},m="\\.([0-9](_?[0-9])*)",E="0|[1-9](_?[0-9])*|0[0-7]*[89][0-9]*",y={
className:"number",variants:[{
begin:`(\\b(${E})((${m})|\\.)?|(${m}))[eE][+-]?([0-9](_?[0-9])*)\\b`},{
begin:`\\b(${E})\\b((${m})\\b|\\.)?|(${m})\\b`},{
begin:"\\b(0|[1-9](_?[0-9])*)n\\b"},{
begin:"\\b0[xX][0-9a-fA-F](_?[0-9a-fA-F])*n?\\b"},{
begin:"\\b0[bB][0-1](_?[0-1])*n?\\b"},{begin:"\\b0[oO][0-7](_?[0-7])*n?\\b"},{
begin:"\\b0[0-7]+n?\\b"}],relevance:0},f={className:"subst",begin:"\\$\\{",
end:"\\}",keywords:u,contains:[]},p={begin:"html`",end:"",starts:{end:"`",
returnEnd:!1,contains:[b.BACKSLASH_ESCAPE,f],subLanguage:"xml"}},_={
begin:"css`",end:"",starts:{end:"`",returnEnd:!1,
contains:[b.BACKSLASH_ESCAPE,f],subLanguage:"css"}},N={className:"string",
begin:"`",end:"`",contains:[b.BACKSLASH_ESCAPE,f]},A={className:"comment",
variants:[b.COMMENT(/\/\*\*(?!\/)/,"\\*/",{relevance:0,contains:[{
begin:"(?=@[A-Za-z]+)",relevance:0,contains:[{className:"doctag",
begin:"@[A-Za-z]+"},{className:"type",begin:"\\{",end:"\\}",excludeEnd:!0,
excludeBegin:!0,relevance:0},{className:"variable",begin:d+"(?=\\s*(-)|$)",
endsParent:!0,relevance:0},{begin:/(?=[^\n])\s/,relevance:0}]}]
}),b.C_BLOCK_COMMENT_MODE,b.C_LINE_COMMENT_MODE]
},v=[b.APOS_STRING_MODE,b.QUOTE_STRING_MODE,p,_,N,y,b.REGEXP_MODE]
;f.contains=v.concat({begin:/\{/,end:/\}/,keywords:u,contains:["self"].concat(v)
});const h=[].concat(A,f.contains),w=h.concat([{begin:/\(/,end:/\)/,keywords:u,
contains:["self"].concat(h)}]),S={className:"params",begin:/\(/,end:/\)/,
excludeBegin:!0,excludeEnd:!0,keywords:u,contains:w},O={variants:[{
match:[/class/,/\s+/,d],scope:{1:"keyword",3:"title.class"}},{
match:[/extends/,/\s+/,l(d,"(",l(/\./,d),")*")],scope:{1:"keyword",
3:"title.class.inherited"}}]},R={relevance:0,
match:/\b[A-Z][a-z]+([A-Z][a-z]+)*/,className:"title.class",keywords:{
_:[...t,...s]}},I={variants:[{match:[/function/,/\s+/,d,/(?=\s*\()/]},{
match:[/function/,/\s*(?=\()/]}],className:{1:"keyword",3:"title.function"},
label:"func.def",contains:[S],illegal:/%/},x={
match:l(/\b/,(T=[...r,"super"],l("(?!",T.join("|"),")")),d,o(/\(/)),
className:"title.function",relevance:0};var T;const k={
begin:l(/\./,o(l(d,/(?![0-9A-Za-z$_(])/))),end:d,excludeBegin:!0,
keywords:"prototype",className:"property",relevance:0},M={
match:[/get|set/,/\s+/,d,/(?=\()/],className:{1:"keyword",3:"title.function"},
contains:[{begin:/\(\)/},S]
},C="(\\([^()]*(\\([^()]*(\\([^()]*\\)[^()]*)*\\)[^()]*)*\\)|"+b.UNDERSCORE_IDENT_RE+")\\s*=>",B={
match:[/const|var|let/,/\s+/,d,/\s*/,/=\s*/,o(C)],className:{1:"keyword",
3:"title.function"},contains:[S]};return{name:"Javascript",
aliases:["js","jsx","mjs","cjs"],keywords:u,exports:{PARAMS_CONTAINS:w},
illegal:/#(?![$_A-z])/,contains:[b.SHEBANG({label:"shebang",binary:"node",
relevance:5}),{label:"use_strict",className:"meta",relevance:10,
begin:/^\s*['"]use (strict|asm)['"]/
},b.APOS_STRING_MODE,b.QUOTE_STRING_MODE,p,_,N,A,y,R,{className:"attr",
begin:d+o(":"),relevance:0},B,{
begin:"("+b.RE_STARTERS_RE+"|\\b(case|return|throw)\\b)\\s*",
keywords:"return throw case",relevance:0,contains:[A,b.REGEXP_MODE,{
className:"function",begin:C,returnBegin:!0,end:"\\s*=>",contains:[{
className:"params",variants:[{begin:b.UNDERSCORE_IDENT_RE,relevance:0},{
className:null,begin:/\(\s*\)/,skip:!0},{begin:/\(/,end:/\)/,excludeBegin:!0,
excludeEnd:!0,keywords:u,contains:w}]}]},{begin:/,/,relevance:0},{match:/\s+/,
relevance:0},{variants:[{begin:"<>",end:"</>"},{begin:g.begin,
"on:begin":g.isTrulyOpeningTag,end:g.end}],subLanguage:"xml",contains:[{
begin:g.begin,end:g.end,skip:!0,contains:["self"]}]}]},I,{
beginKeywords:"while if switch catch for"},{
begin:"\\b(?!function)"+b.UNDERSCORE_IDENT_RE+"\\([^()]*(\\([^()]*(\\([^()]*\\)[^()]*)*\\)[^()]*)*\\)\\s*\\{",
returnBegin:!0,label:"func.def",contains:[S,b.inherit(b.TITLE_MODE,{begin:d,
className:"title.function"})]},{match:/\.\.\./,relevance:0},k,{match:"\\$"+d,
relevance:0},{match:[/\bconstructor(?=\s*\()/],className:{1:"title.function"},
contains:[S]},x,{relevance:0,match:/\b[A-Z][A-Z_0-9]+\b/,
className:"variable.constant"},O,M,{match:/\$[(.]/}]}}(b)
;return Object.assign(m.keywords,d),
m.exports.PARAMS_CONTAINS.push(g),m.contains=m.contains.concat([g,{
beginKeywords:"namespace",end:/\{/,excludeEnd:!0},{beginKeywords:"interface",
end:/\{/,excludeEnd:!0,keywords:"interface extends"
}]),u(m,"shebang",b.SHEBANG()),u(m,"use_strict",{className:"meta",relevance:10,
begin:/^\s*['"]use strict['"]/
}),m.contains.find((e=>"func.def"===e.label)).relevance=0,Object.assign(m,{
name:"TypeScript",aliases:["ts","tsx"]}),m}})());