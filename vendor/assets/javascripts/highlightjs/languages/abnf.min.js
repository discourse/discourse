hljs.registerLanguage("abnf",(()=>{"use strict";function e(...e){
return e.map((e=>{return(a=e)?"string"==typeof a?a:a.source:null;var a
})).join("")}return a=>{const s={ruleDeclaration:/^[a-zA-Z][a-zA-Z0-9-]*/,
unexpectedChars:/[!@#$^&',?+~`|:]/},n=a.COMMENT(/;/,/$/),r={
className:"attribute",begin:e(s.ruleDeclaration,/(?=\s*=)/)};return{
name:"Augmented Backus-Naur Form",illegal:s.unexpectedChars,
keywords:["ALPHA","BIT","CHAR","CR","CRLF","CTL","DIGIT","DQUOTE","HEXDIG","HTAB","LF","LWSP","OCTET","SP","VCHAR","WSP"],
contains:[r,n,{className:"symbol",begin:/%b[0-1]+(-[0-1]+|(\.[0-1]+)+){0,1}/},{
className:"symbol",begin:/%d[0-9]+(-[0-9]+|(\.[0-9]+)+){0,1}/},{
className:"symbol",begin:/%x[0-9A-F]+(-[0-9A-F]+|(\.[0-9A-F]+)+){0,1}/},{
className:"symbol",begin:/%[si]/},a.QUOTE_STRING_MODE,a.NUMBER_MODE]}}})());