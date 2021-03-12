hljs.registerLanguage("typescript",(()=>{"use strict"
;const e="[A-Za-z$_][0-9A-Za-z$_]*",n=["as","in","of","if","for","while","finally","var","new","function","do","return","void","else","break","catch","instanceof","with","throw","case","default","try","switch","continue","typeof","delete","let","yield","const","class","debugger","async","await","static","import","from","export","extends"],a=["true","false","null","undefined","NaN","Infinity"],s=[].concat(["setInterval","setTimeout","clearInterval","clearTimeout","require","exports","eval","isFinite","isNaN","parseFloat","parseInt","decodeURI","decodeURIComponent","encodeURI","encodeURIComponent","escape","unescape"],["arguments","this","super","console","window","document","localStorage","module","global"],["Intl","DataView","Number","Math","Date","String","RegExp","Object","Function","Boolean","Error","Symbol","Set","Map","WeakSet","WeakMap","Proxy","Reflect","JSON","Promise","Float64Array","Int16Array","Int32Array","Int8Array","Uint16Array","Uint32Array","Float32Array","Array","Uint8Array","Uint8ClampedArray","ArrayBuffer","BigInt64Array","BigUint64Array","BigInt"],["EvalError","InternalError","RangeError","ReferenceError","SyntaxError","TypeError","URIError"])
;function t(e){return r("(?=",e,")")}function r(...e){return e.map((e=>{
return(n=e)?"string"==typeof n?n:n.source:null;var n})).join("")}return i=>{
const c={$pattern:e,
keyword:n.concat(["type","namespace","typedef","interface","public","private","protected","implements","declare","abstract","readonly"]),
literal:a,
built_in:s.concat(["any","void","number","boolean","string","object","never","enum"])
},o={className:"meta",begin:"@[A-Za-z$_][0-9A-Za-z$_]*"},l=(e,n,a)=>{
const s=e.contains.findIndex((e=>e.label===n))
;if(-1===s)throw Error("can not find mode to replace");e.contains.splice(s,1,a)
},b=(i=>{const c=e,o={begin:/<[A-Za-z0-9\\._:-]+/,
end:/\/[A-Za-z0-9\\._:-]+>|\/>/,isTrulyOpeningTag:(e,n)=>{
const a=e[0].length+e.index,s=e.input[a];"<"!==s?">"===s&&(((e,{after:n})=>{
const a="</"+e[0].slice(1);return-1!==e.input.indexOf(a,n)})(e,{after:a
})||n.ignoreMatch()):n.ignoreMatch()}},l={$pattern:e,keyword:n,literal:a,
built_in:s},b="\\.([0-9](_?[0-9])*)",d="0|[1-9](_?[0-9])*|0[0-7]*[89][0-9]*",g={
className:"number",variants:[{
begin:`(\\b(${d})((${b})|\\.)?|(${b}))[eE][+-]?([0-9](_?[0-9])*)\\b`},{
begin:`\\b(${d})\\b((${b})\\b|\\.)?|(${b})\\b`},{
begin:"\\b(0|[1-9](_?[0-9])*)n\\b"},{
begin:"\\b0[xX][0-9a-fA-F](_?[0-9a-fA-F])*n?\\b"},{
begin:"\\b0[bB][0-1](_?[0-1])*n?\\b"},{begin:"\\b0[oO][0-7](_?[0-7])*n?\\b"},{
begin:"\\b0[0-7]+n?\\b"}],relevance:0},u={className:"subst",begin:"\\$\\{",
end:"\\}",keywords:l,contains:[]},E={begin:"html`",end:"",starts:{end:"`",
returnEnd:!1,contains:[i.BACKSLASH_ESCAPE,u],subLanguage:"xml"}},m={
begin:"css`",end:"",starts:{end:"`",returnEnd:!1,
contains:[i.BACKSLASH_ESCAPE,u],subLanguage:"css"}},y={className:"string",
begin:"`",end:"`",contains:[i.BACKSLASH_ESCAPE,u]},_={className:"comment",
variants:[i.COMMENT(/\/\*\*(?!\/)/,"\\*/",{relevance:0,contains:[{
className:"doctag",begin:"@[A-Za-z]+",contains:[{className:"type",begin:"\\{",
end:"\\}",relevance:0},{className:"variable",begin:c+"(?=\\s*(-)|$)",
endsParent:!0,relevance:0},{begin:/(?=[^\n])\s/,relevance:0}]}]
}),i.C_BLOCK_COMMENT_MODE,i.C_LINE_COMMENT_MODE]
},p=[i.APOS_STRING_MODE,i.QUOTE_STRING_MODE,E,m,y,g,i.REGEXP_MODE]
;u.contains=p.concat({begin:/\{/,end:/\}/,keywords:l,contains:["self"].concat(p)
});const N=[].concat(_,u.contains),f=N.concat([{begin:/\(/,end:/\)/,keywords:l,
contains:["self"].concat(N)}]),A={className:"params",begin:/\(/,end:/\)/,
excludeBegin:!0,excludeEnd:!0,keywords:l,contains:f};return{name:"Javascript",
aliases:["js","jsx","mjs","cjs"],keywords:l,exports:{PARAMS_CONTAINS:f},
illegal:/#(?![$_A-z])/,contains:[i.SHEBANG({label:"shebang",binary:"node",
relevance:5}),{label:"use_strict",className:"meta",relevance:10,
begin:/^\s*['"]use (strict|asm)['"]/
},i.APOS_STRING_MODE,i.QUOTE_STRING_MODE,E,m,y,_,g,{
begin:r(/[{,\n]\s*/,t(r(/(((\/\/.*$)|(\/\*(\*[^/]|[^*])*\*\/))\s*)*/,c+"\\s*:"))),
relevance:0,contains:[{className:"attr",begin:c+t("\\s*:"),relevance:0}]},{
begin:"("+i.RE_STARTERS_RE+"|\\b(case|return|throw)\\b)\\s*",
keywords:"return throw case",contains:[_,i.REGEXP_MODE,{className:"function",
begin:"(\\([^()]*(\\([^()]*(\\([^()]*\\)[^()]*)*\\)[^()]*)*\\)|"+i.UNDERSCORE_IDENT_RE+")\\s*=>",
returnBegin:!0,end:"\\s*=>",contains:[{className:"params",variants:[{
begin:i.UNDERSCORE_IDENT_RE,relevance:0},{className:null,begin:/\(\s*\)/,skip:!0
},{begin:/\(/,end:/\)/,excludeBegin:!0,excludeEnd:!0,keywords:l,contains:f}]}]
},{begin:/,/,relevance:0},{className:"",begin:/\s/,end:/\s*/,skip:!0},{
variants:[{begin:"<>",end:"</>"},{begin:o.begin,"on:begin":o.isTrulyOpeningTag,
end:o.end}],subLanguage:"xml",contains:[{begin:o.begin,end:o.end,skip:!0,
contains:["self"]}]}],relevance:0},{className:"function",
beginKeywords:"function",end:/[{;]/,excludeEnd:!0,keywords:l,
contains:["self",i.inherit(i.TITLE_MODE,{begin:c}),A],illegal:/%/},{
beginKeywords:"while if switch catch for"},{className:"function",
begin:i.UNDERSCORE_IDENT_RE+"\\([^()]*(\\([^()]*(\\([^()]*\\)[^()]*)*\\)[^()]*)*\\)\\s*\\{",
returnBegin:!0,contains:[A,i.inherit(i.TITLE_MODE,{begin:c})]},{variants:[{
begin:"\\."+c},{begin:"\\$"+c}],relevance:0},{className:"class",
beginKeywords:"class",end:/[{;=]/,excludeEnd:!0,illegal:/[:"[\]]/,contains:[{
beginKeywords:"extends"},i.UNDERSCORE_TITLE_MODE]},{begin:/\b(?=constructor)/,
end:/[{;]/,excludeEnd:!0,contains:[i.inherit(i.TITLE_MODE,{begin:c}),"self",A]
},{begin:"(get|set)\\s+(?="+c+"\\()",end:/\{/,keywords:"get set",
contains:[i.inherit(i.TITLE_MODE,{begin:c}),{begin:/\(\)/},A]},{begin:/\$[(.]/}]
}})(i)
;return Object.assign(b.keywords,c),b.exports.PARAMS_CONTAINS.push(o),b.contains=b.contains.concat([o,{
beginKeywords:"namespace",end:/\{/,excludeEnd:!0},{beginKeywords:"interface",
end:/\{/,excludeEnd:!0,keywords:"interface extends"
}]),l(b,"shebang",i.SHEBANG()),l(b,"use_strict",{className:"meta",relevance:10,
begin:/^\s*['"]use strict['"]/
}),b.contains.find((e=>"function"===e.className)).relevance=0,Object.assign(b,{
name:"TypeScript",aliases:["ts","tsx"]}),b}})());