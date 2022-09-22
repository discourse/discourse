/*! `abnf` grammar compiled for Highlight.js 11.6.0 */
(()=>{var e=(()=>{"use strict";return e=>{const a=e.regex,s=e.COMMENT(/;/,/$/)
;return{name:"Augmented Backus-Naur Form",illegal:/[!@#$^&',?+~`|:]/,
keywords:["ALPHA","BIT","CHAR","CR","CRLF","CTL","DIGIT","DQUOTE","HEXDIG","HTAB","LF","LWSP","OCTET","SP","VCHAR","WSP"],
contains:[{scope:"operator",match:/=\/?/},{scope:"attribute",
match:a.concat(/^[a-zA-Z][a-zA-Z0-9-]*/,/(?=\s*=)/)},s,{scope:"symbol",
match:/%b[0-1]+(-[0-1]+|(\.[0-1]+)+)?/},{scope:"symbol",
match:/%d[0-9]+(-[0-9]+|(\.[0-9]+)+)?/},{scope:"symbol",
match:/%x[0-9A-F]+(-[0-9A-F]+|(\.[0-9A-F]+)+)?/},{scope:"symbol",
match:/%[si](?=".*")/},e.QUOTE_STRING_MODE,e.NUMBER_MODE]}}})()
;hljs.registerLanguage("abnf",e)})();