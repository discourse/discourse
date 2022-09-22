/*! `handlebars` grammar compiled for Highlight.js 11.6.0 */
(()=>{var e=(()=>{"use strict";return e=>{const a=e.regex,n={
$pattern:/[\w.\/]+/,
built_in:["action","bindattr","collection","component","concat","debugger","each","each-in","get","hash","if","in","input","link-to","loc","log","lookup","mut","outlet","partial","query-params","render","template","textarea","unbound","unless","view","with","yield"]
},t=/\[\]|\[[^\]]+\]/,s=/[^\s!"#%&'()*+,.\/;<=>@\[\\\]^`{|}~]+/,i=a.either(/""|"[^"]+"/,/''|'[^']+'/,t,s),r=a.concat(a.optional(/\.|\.\/|\//),i,a.anyNumberOfTimes(a.concat(/(\.|\/)/,i))),l=a.concat("(",t,"|",s,")(?==)"),c={
begin:r},o=e.inherit(c,{keywords:{$pattern:/[\w.\/]+/,
literal:["true","false","undefined","null"]}}),m={begin:/\(/,end:/\)/},d={
className:"attr",begin:l,relevance:0,starts:{begin:/=/,end:/=/,starts:{
contains:[e.NUMBER_MODE,e.QUOTE_STRING_MODE,e.APOS_STRING_MODE,o,m]}}},g={
contains:[e.NUMBER_MODE,e.QUOTE_STRING_MODE,e.APOS_STRING_MODE,{begin:/as\s+\|/,
keywords:{keyword:"as"},end:/\|/,contains:[{begin:/\w+/}]},d,o,m],returnEnd:!0
},b=e.inherit(c,{className:"name",keywords:n,starts:e.inherit(g,{end:/\)/})})
;m.contains=[b];const u=e.inherit(c,{keywords:n,className:"name",
starts:e.inherit(g,{end:/\}\}/})}),h=e.inherit(c,{keywords:n,className:"name"
}),N=e.inherit(c,{className:"name",keywords:n,starts:e.inherit(g,{end:/\}\}/})})
;return{name:"Handlebars",
aliases:["hbs","html.hbs","html.handlebars","htmlbars"],case_insensitive:!0,
subLanguage:"xml",contains:[{begin:/\\\{\{/,skip:!0},{begin:/\\\\(?=\{\{)/,
skip:!0},e.COMMENT(/\{\{!--/,/--\}\}/),e.COMMENT(/\{\{!/,/\}\}/),{
className:"template-tag",begin:/\{\{\{\{(?!\/)/,end:/\}\}\}\}/,contains:[u],
starts:{end:/\{\{\{\{\//,returnEnd:!0,subLanguage:"xml"}},{
className:"template-tag",begin:/\{\{\{\{\//,end:/\}\}\}\}/,contains:[h]},{
className:"template-tag",begin:/\{\{#/,end:/\}\}/,contains:[u]},{
className:"template-tag",begin:/\{\{(?=else\}\})/,end:/\}\}/,keywords:"else"},{
className:"template-tag",begin:/\{\{(?=else if)/,end:/\}\}/,keywords:"else if"
},{className:"template-tag",begin:/\{\{\//,end:/\}\}/,contains:[h]},{
className:"template-variable",begin:/\{\{\{/,end:/\}\}\}/,contains:[N]},{
className:"template-variable",begin:/\{\{/,end:/\}\}/,contains:[N]}]}}})()
;hljs.registerLanguage("handlebars",e)})();