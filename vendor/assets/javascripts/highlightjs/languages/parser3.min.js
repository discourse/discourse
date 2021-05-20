hljs.registerLanguage("parser3",(()=>{"use strict";return e=>{
const a=e.COMMENT(/\{/,/\}/,{contains:["self"]});return{name:"Parser3",
subLanguage:"xml",relevance:0,
contains:[e.COMMENT("^#","$"),e.COMMENT(/\^rem\{/,/\}/,{relevance:10,
contains:[a]}),{className:"meta",begin:"^@(?:BASE|USE|CLASS|OPTIONS)$",
relevance:10},{className:"title",
begin:"@[\\w\\-]+\\[[\\w^;\\-]*\\](?:\\[[\\w^;\\-]*\\])?(?:.*)$"},{
className:"variable",begin:/\$\{?[\w\-.:]+\}?/},{className:"keyword",
begin:/\^[\w\-.:]+/},{className:"number",begin:"\\^#[0-9a-fA-F]+"
},e.C_NUMBER_MODE]}}})());