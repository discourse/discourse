hljs.registerLanguage("livescript",(()=>{"use strict"
;const e=["as","in","of","if","for","while","finally","var","new","function","do","return","void","else","break","catch","instanceof","with","throw","case","default","try","switch","continue","typeof","delete","let","yield","const","class","debugger","async","await","static","import","from","export","extends"],n=["true","false","null","undefined","NaN","Infinity"],a=[].concat(["setInterval","setTimeout","clearInterval","clearTimeout","require","exports","eval","isFinite","isNaN","parseFloat","parseInt","decodeURI","decodeURIComponent","encodeURI","encodeURIComponent","escape","unescape"],["Intl","DataView","Number","Math","Date","String","RegExp","Object","Function","Boolean","Error","Symbol","Set","Map","WeakSet","WeakMap","Proxy","Reflect","JSON","Promise","Float64Array","Int16Array","Int32Array","Int8Array","Uint16Array","Uint32Array","Float32Array","Array","Uint8Array","Uint8ClampedArray","ArrayBuffer","BigInt64Array","BigUint64Array","BigInt"],["EvalError","InternalError","RangeError","ReferenceError","SyntaxError","TypeError","URIError"])
;return t=>{const r={
keyword:e.concat(["then","unless","until","loop","of","by","when","and","or","is","isnt","not","it","that","otherwise","from","to","til","fallthrough","case","enum","native","list","map","__hasProp","__extends","__slice","__bind","__indexOf"]),
literal:n.concat(["yes","no","on","off","it","that","void"]),
built_in:a.concat(["npm","print"])
},i="[A-Za-z$_](?:-[0-9A-Za-z$_]|[0-9A-Za-z$_])*",s=t.inherit(t.TITLE_MODE,{
begin:i}),o={className:"subst",begin:/#\{/,end:/\}/,keywords:r},c={
className:"subst",begin:/#[A-Za-z$_]/,end:/(?:-[0-9A-Za-z$_]|[0-9A-Za-z$_])*/,
keywords:r},l=[t.BINARY_NUMBER_MODE,{className:"number",
begin:"(\\b0[xX][a-fA-F0-9_]+)|(\\b\\d(\\d|_\\d)*(\\.(\\d(\\d|_\\d)*)?)?(_*[eE]([-+]\\d(_\\d|\\d)*)?)?[_a-z]*)",
relevance:0,starts:{end:"(\\s*/)?",relevance:0}},{className:"string",variants:[{
begin:/'''/,end:/'''/,contains:[t.BACKSLASH_ESCAPE]},{begin:/'/,end:/'/,
contains:[t.BACKSLASH_ESCAPE]},{begin:/"""/,end:/"""/,
contains:[t.BACKSLASH_ESCAPE,o,c]},{begin:/"/,end:/"/,
contains:[t.BACKSLASH_ESCAPE,o,c]},{begin:/\\/,end:/(\s|$)/,excludeEnd:!0}]},{
className:"regexp",variants:[{begin:"//",end:"//[gim]*",
contains:[o,t.HASH_COMMENT_MODE]},{
begin:/\/(?![ *])(\\.|[^\\\n])*?\/[gim]*(?=\W)/}]},{begin:"@"+i},{begin:"``",
end:"``",excludeBegin:!0,excludeEnd:!0,subLanguage:"javascript"}];o.contains=l
;const d={className:"params",begin:"\\(",returnBegin:!0,contains:[{begin:/\(/,
end:/\)/,keywords:r,contains:["self"].concat(l)}]};return{name:"LiveScript",
aliases:["ls"],keywords:r,illegal:/\/\*/,
contains:l.concat([t.COMMENT("\\/\\*","\\*\\/"),t.HASH_COMMENT_MODE,{
begin:"(#=>|=>|\\|>>|-?->|!->)"},{className:"function",contains:[s,d],
returnBegin:!0,variants:[{
begin:"("+i+"\\s*(?:=|:=)\\s*)?(\\(.*\\)\\s*)?\\B->\\*?",end:"->\\*?"},{
begin:"("+i+"\\s*(?:=|:=)\\s*)?!?(\\(.*\\)\\s*)?\\B[-~]{1,2}>\\*?",
end:"[-~]{1,2}>\\*?"},{
begin:"("+i+"\\s*(?:=|:=)\\s*)?(\\(.*\\)\\s*)?\\B!?[-~]{1,2}>\\*?",
end:"!?[-~]{1,2}>\\*?"}]},{className:"class",beginKeywords:"class",end:"$",
illegal:/[:="\[\]]/,contains:[{beginKeywords:"extends",endsWithParent:!0,
illegal:/[:="\[\]]/,contains:[s]},s]},{begin:i+":",end:":",returnBegin:!0,
returnEnd:!0,relevance:0}])}}})());