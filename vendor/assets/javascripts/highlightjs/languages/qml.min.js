hljs.registerLanguage("qml",(()=>{"use strict";function e(...e){
return e.map((e=>{return(n=e)?"string"==typeof n?n:n.source:null;var n
})).join("")}return n=>{const r="[a-zA-Z_][a-zA-Z0-9\\._]*",a={
className:"attribute",begin:"\\bid\\s*:",starts:{className:"string",end:r,
returnEnd:!1}},t={begin:r+"\\s*:",returnBegin:!0,contains:[{
className:"attribute",begin:r,end:"\\s*:",excludeEnd:!0,relevance:0}],
relevance:0},i={begin:e(r,/\s*\{/),end:/\{/,returnBegin:!0,relevance:0,
contains:[n.inherit(n.TITLE_MODE,{begin:r})]};return{name:"QML",aliases:["qt"],
case_insensitive:!1,keywords:{
keyword:"in of on if for while finally var new function do return void else break catch instanceof with throw case default try this switch continue typeof delete let yield const export super debugger as async await import",
literal:"true false null undefined NaN Infinity",
built_in:"eval isFinite isNaN parseFloat parseInt decodeURI decodeURIComponent encodeURI encodeURIComponent escape unescape Object Function Boolean Error EvalError InternalError RangeError ReferenceError StopIteration SyntaxError TypeError URIError Number Math Date String RegExp Array Float32Array Float64Array Int16Array Int32Array Int8Array Uint16Array Uint32Array Uint8Array Uint8ClampedArray ArrayBuffer DataView JSON Intl arguments require module console window document Symbol Set Map WeakSet WeakMap Proxy Reflect Behavior bool color coordinate date double enumeration font geocircle georectangle geoshape int list matrix4x4 parent point quaternion real rect size string url variant vector2d vector3d vector4d Promise"
},contains:[{className:"meta",begin:/^\s*['"]use (strict|asm)['"]/
},n.APOS_STRING_MODE,n.QUOTE_STRING_MODE,{className:"string",begin:"`",end:"`",
contains:[n.BACKSLASH_ESCAPE,{className:"subst",begin:"\\$\\{",end:"\\}"}]
},n.C_LINE_COMMENT_MODE,n.C_BLOCK_COMMENT_MODE,{className:"number",variants:[{
begin:"\\b(0[bB][01]+)"},{begin:"\\b(0[oO][0-7]+)"},{begin:n.C_NUMBER_RE}],
relevance:0},{begin:"("+n.RE_STARTERS_RE+"|\\b(case|return|throw)\\b)\\s*",
keywords:"return throw case",
contains:[n.C_LINE_COMMENT_MODE,n.C_BLOCK_COMMENT_MODE,n.REGEXP_MODE,{begin:/</,
end:/>\s*[);\]]/,relevance:0,subLanguage:"xml"}],relevance:0},{
className:"keyword",begin:"\\bsignal\\b",starts:{className:"string",
end:"(\\(|:|=|;|,|//|/\\*|$)",returnEnd:!0}},{className:"keyword",
begin:"\\bproperty\\b",starts:{className:"string",end:"(:|=|;|,|//|/\\*|$)",
returnEnd:!0}},{className:"function",beginKeywords:"function",end:/\{/,
excludeEnd:!0,contains:[n.inherit(n.TITLE_MODE,{begin:/[A-Za-z$_][0-9A-Za-z$_]*/
}),{className:"params",begin:/\(/,end:/\)/,excludeBegin:!0,excludeEnd:!0,
contains:[n.C_LINE_COMMENT_MODE,n.C_BLOCK_COMMENT_MODE]}],illegal:/\[|%/},{
begin:"\\."+n.IDENT_RE,relevance:0},a,t,i],illegal:/#/}}})());