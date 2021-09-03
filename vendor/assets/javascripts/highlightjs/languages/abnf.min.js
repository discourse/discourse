hljs.registerLanguage("abnf",(()=>{"use strict";function e(...e){
return e.map((e=>{return(t=e)?"string"==typeof t?t:t.source:null;var t
})).join("")}return t=>{const s=t.COMMENT(/;/,/$/);return{
name:"Augmented Backus-Naur Form",illegal:/[!@#$^&',?+~`|:]/,
keywords:["ALPHA","BIT","CHAR","CR","CRLF","CTL","DIGIT","DQUOTE","HEXDIG","HTAB","LF","LWSP","OCTET","SP","VCHAR","WSP"],
contains:[{scope:"operator",match:/=\/?/},{scope:"attribute",
match:e(/^[a-zA-Z][a-zA-Z0-9-]*/,/(?=\s*=)/)},s,{scope:"symbol",
match:/%b[0-1]+(-[0-1]+|(\.[0-1]+)+)?/},{scope:"symbol",
match:/%d[0-9]+(-[0-9]+|(\.[0-9]+)+)?/},{scope:"symbol",
match:/%x[0-9A-F]+(-[0-9A-F]+|(\.[0-9A-F]+)+)?/},{scope:"symbol",
match:/%[si](?=".*")/},t.QUOTE_STRING_MODE,t.NUMBER_MODE]}}})());