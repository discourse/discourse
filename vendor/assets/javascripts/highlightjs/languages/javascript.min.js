hljs.registerLanguage("javascript",(()=>{"use strict"
;const e="[A-Za-z$_][0-9A-Za-z$_]*",n=["as","in","of","if","for","while","finally","var","new","function","do","return","void","else","break","catch","instanceof","with","throw","case","default","try","switch","continue","typeof","delete","let","yield","const","class","debugger","async","await","static","import","from","export","extends"],a=["true","false","null","undefined","NaN","Infinity"],t=["Intl","DataView","Number","Math","Date","String","RegExp","Object","Function","Boolean","Error","Symbol","Set","Map","WeakSet","WeakMap","Proxy","Reflect","JSON","Promise","Float64Array","Int16Array","Int32Array","Int8Array","Uint16Array","Uint32Array","Float32Array","Array","Uint8Array","Uint8ClampedArray","ArrayBuffer","BigInt64Array","BigUint64Array","BigInt"],s=["EvalError","InternalError","RangeError","ReferenceError","SyntaxError","TypeError","URIError"],r=["setInterval","setTimeout","clearInterval","clearTimeout","require","exports","eval","isFinite","isNaN","parseFloat","parseInt","decodeURI","decodeURIComponent","encodeURI","encodeURIComponent","escape","unescape"],i=["arguments","this","super","console","window","document","localStorage","module","global"],c=[].concat(r,t,s)
;function o(e){return l("(?=",e,")")}function l(...e){return e.map((e=>{
return(n=e)?"string"==typeof n?n:n.source:null;var n})).join("")}return b=>{
const g=e,d={begin:/<[A-Za-z0-9\\._:-]+/,end:/\/[A-Za-z0-9\\._:-]+>|\/>/,
isTrulyOpeningTag:(e,n)=>{const a=e[0].length+e.index,t=e.input[a]
;"<"!==t?">"===t&&(((e,{after:n})=>{const a="</"+e[0].slice(1)
;return-1!==e.input.indexOf(a,n)})(e,{after:a
})||n.ignoreMatch()):n.ignoreMatch()}},u={$pattern:e,keyword:n,literal:a,
built_in:c,"variable.language":i
},m="\\.([0-9](_?[0-9])*)",E="0|[1-9](_?[0-9])*|0[0-7]*[89][0-9]*",y={
className:"number",variants:[{
begin:`(\\b(${E})((${m})|\\.)?|(${m}))[eE][+-]?([0-9](_?[0-9])*)\\b`},{
begin:`\\b(${E})\\b((${m})\\b|\\.)?|(${m})\\b`},{
begin:"\\b(0|[1-9](_?[0-9])*)n\\b"},{
begin:"\\b0[xX][0-9a-fA-F](_?[0-9a-fA-F])*n?\\b"},{
begin:"\\b0[bB][0-1](_?[0-1])*n?\\b"},{begin:"\\b0[oO][0-7](_?[0-7])*n?\\b"},{
begin:"\\b0[0-7]+n?\\b"}],relevance:0},_={className:"subst",begin:"\\$\\{",
end:"\\}",keywords:u,contains:[]},N={begin:"html`",end:"",starts:{end:"`",
returnEnd:!1,contains:[b.BACKSLASH_ESCAPE,_],subLanguage:"xml"}},f={
begin:"css`",end:"",starts:{end:"`",returnEnd:!1,
contains:[b.BACKSLASH_ESCAPE,_],subLanguage:"css"}},A={className:"string",
begin:"`",end:"`",contains:[b.BACKSLASH_ESCAPE,_]},v={className:"comment",
variants:[b.COMMENT(/\/\*\*(?!\/)/,"\\*/",{relevance:0,contains:[{
begin:"(?=@[A-Za-z]+)",relevance:0,contains:[{className:"doctag",
begin:"@[A-Za-z]+"},{className:"type",begin:"\\{",end:"\\}",excludeEnd:!0,
excludeBegin:!0,relevance:0},{className:"variable",begin:g+"(?=\\s*(-)|$)",
endsParent:!0,relevance:0},{begin:/(?=[^\n])\s/,relevance:0}]}]
}),b.C_BLOCK_COMMENT_MODE,b.C_LINE_COMMENT_MODE]
},p=[b.APOS_STRING_MODE,b.QUOTE_STRING_MODE,N,f,A,y,b.REGEXP_MODE]
;_.contains=p.concat({begin:/\{/,end:/\}/,keywords:u,contains:["self"].concat(p)
});const h=[].concat(v,_.contains),S=h.concat([{begin:/\(/,end:/\)/,keywords:u,
contains:["self"].concat(h)}]),w={className:"params",begin:/\(/,end:/\)/,
excludeBegin:!0,excludeEnd:!0,keywords:u,contains:S},R={variants:[{
match:[/class/,/\s+/,g],scope:{1:"keyword",3:"title.class"}},{
match:[/extends/,/\s+/,l(g,"(",l(/\./,g),")*")],scope:{1:"keyword",
3:"title.class.inherited"}}]},O={relevance:0,
match:/\b[A-Z][a-z]+([A-Z][a-z]+)*/,className:"title.class",keywords:{
_:[...t,...s]}},I={variants:[{match:[/function/,/\s+/,g,/(?=\s*\()/]},{
match:[/function/,/\s*(?=\()/]}],className:{1:"keyword",3:"title.function"},
label:"func.def",contains:[w],illegal:/%/},T={
match:l(/\b/,(x=[...r,"super"],l("(?!",x.join("|"),")")),g,o(/\(/)),
className:"title.function",relevance:0};var x;const M={
begin:l(/\./,o(l(g,/(?![0-9A-Za-z$_(])/))),end:g,excludeBegin:!0,
keywords:"prototype",className:"property",relevance:0},k={
match:[/get|set/,/\s+/,g,/(?=\()/],className:{1:"keyword",3:"title.function"},
contains:[{begin:/\(\)/},w]
},C="(\\([^()]*(\\([^()]*(\\([^()]*\\)[^()]*)*\\)[^()]*)*\\)|"+b.UNDERSCORE_IDENT_RE+")\\s*=>",B={
match:[/const|var|let/,/\s+/,g,/\s*/,/=\s*/,o(C)],className:{1:"keyword",
3:"title.function"},contains:[w]};return{name:"Javascript",
aliases:["js","jsx","mjs","cjs"],keywords:u,exports:{PARAMS_CONTAINS:S},
illegal:/#(?![$_A-z])/,contains:[b.SHEBANG({label:"shebang",binary:"node",
relevance:5}),{label:"use_strict",className:"meta",relevance:10,
begin:/^\s*['"]use (strict|asm)['"]/
},b.APOS_STRING_MODE,b.QUOTE_STRING_MODE,N,f,A,v,y,O,{className:"attr",
begin:g+o(":"),relevance:0},B,{
begin:"("+b.RE_STARTERS_RE+"|\\b(case|return|throw)\\b)\\s*",
keywords:"return throw case",relevance:0,contains:[v,b.REGEXP_MODE,{
className:"function",begin:C,returnBegin:!0,end:"\\s*=>",contains:[{
className:"params",variants:[{begin:b.UNDERSCORE_IDENT_RE,relevance:0},{
className:null,begin:/\(\s*\)/,skip:!0},{begin:/\(/,end:/\)/,excludeBegin:!0,
excludeEnd:!0,keywords:u,contains:S}]}]},{begin:/,/,relevance:0},{match:/\s+/,
relevance:0},{variants:[{begin:"<>",end:"</>"},{begin:d.begin,
"on:begin":d.isTrulyOpeningTag,end:d.end}],subLanguage:"xml",contains:[{
begin:d.begin,end:d.end,skip:!0,contains:["self"]}]}]},I,{
beginKeywords:"while if switch catch for"},{
begin:"\\b(?!function)"+b.UNDERSCORE_IDENT_RE+"\\([^()]*(\\([^()]*(\\([^()]*\\)[^()]*)*\\)[^()]*)*\\)\\s*\\{",
returnBegin:!0,label:"func.def",contains:[w,b.inherit(b.TITLE_MODE,{begin:g,
className:"title.function"})]},{match:/\.\.\./,relevance:0},M,{match:"\\$"+g,
relevance:0},{match:[/\bconstructor(?=\s*\()/],className:{1:"title.function"},
contains:[w]},T,{relevance:0,match:/\b[A-Z][A-Z_0-9]+\b/,
className:"variable.constant"},R,k,{match:/\$[(.]/}]}}})());