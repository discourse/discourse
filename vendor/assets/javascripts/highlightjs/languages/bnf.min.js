hljs.registerLanguage("bnf",(()=>{"use strict";return e=>({
name:"Backus\u2013Naur Form",contains:[{className:"attribute",begin:/</,end:/>/
},{begin:/::=/,end:/$/,contains:[{begin:/</,end:/>/
},e.C_LINE_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE,e.APOS_STRING_MODE,e.QUOTE_STRING_MODE]
}]})})());