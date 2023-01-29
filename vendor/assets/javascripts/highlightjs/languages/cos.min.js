/*! `cos` grammar compiled for Highlight.js 11.6.0 */
(()=>{var e=(()=>{"use strict";return e=>({name:"Cach\xe9 Object Script",
case_insensitive:!0,aliases:["cls"],
keywords:"property parameter class classmethod clientmethod extends as break catch close continue do d|0 else elseif for goto halt hang h|0 if job j|0 kill k|0 lock l|0 merge new open quit q|0 read r|0 return set s|0 tcommit throw trollback try tstart use view while write w|0 xecute x|0 zkill znspace zn ztrap zwrite zw zzdump zzwrite print zbreak zinsert zload zprint zremove zsave zzprint mv mvcall mvcrt mvdim mvprint zquit zsync ascii",
contains:[{className:"number",begin:"\\b(\\d+(\\.\\d*)?|\\.\\d+)",relevance:0},{
className:"string",variants:[{begin:'"',end:'"',contains:[{begin:'""',
relevance:0}]}]},e.C_LINE_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE,{
className:"comment",begin:/;/,end:"$",relevance:0},{className:"built_in",
begin:/(?:\$\$?|\.\.)\^?[a-zA-Z]+/},{className:"built_in",
begin:/\$\$\$[a-zA-Z]+/},{className:"built_in",begin:/%[a-z]+(?:\.[a-z]+)*/},{
className:"symbol",begin:/\^%?[a-zA-Z][\w]*/},{className:"keyword",
begin:/##class|##super|#define|#dim/},{begin:/&sql\(/,end:/\)/,excludeBegin:!0,
excludeEnd:!0,subLanguage:"sql"},{begin:/&(js|jscript|javascript)</,end:/>/,
excludeBegin:!0,excludeEnd:!0,subLanguage:"javascript"},{begin:/&html<\s*</,
end:/>\s*>/,subLanguage:"xml"}]})})();hljs.registerLanguage("cos",e)})();