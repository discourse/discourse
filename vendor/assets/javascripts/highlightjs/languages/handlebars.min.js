hljs.registerLanguage("handlebars",(()=>{"use strict";function e(e){
return e?"string"==typeof e?e:e.source:null}function n(...n){
return n.map((n=>e(n))).join("")}return a=>{const t={
"builtin-name":["action","bindattr","collection","component","concat","debugger","each","each-in","get","hash","if","in","input","link-to","loc","log","lookup","mut","outlet","partial","query-params","render","template","textarea","unbound","unless","view","with","yield"]
},s=/\[\]|\[[^\]]+\]/,i=/[^\s!"#%&'()*+,.\/;<=>@\[\\\]^`{|}~]+/,r=((...n)=>"("+n.map((n=>e(n))).join("|")+")")(/""|"[^"]+"/,/''|'[^']+'/,s,i),l=n(n("(",/\.|\.\/|\//,")?"),r,(h=n(/(\.|\/)/,r),
n("(",h,")*"))),c=n("(",s,"|",i,")(?==)"),o={begin:l,lexemes:/[\w.\/]+/
},m=a.inherit(o,{keywords:{literal:["true","false","undefined","null"]}}),d={
begin:/\(/,end:/\)/},g={className:"attr",begin:c,relevance:0,starts:{begin:/=/,
end:/=/,starts:{
contains:[a.NUMBER_MODE,a.QUOTE_STRING_MODE,a.APOS_STRING_MODE,m,d]}}},b={
contains:[a.NUMBER_MODE,a.QUOTE_STRING_MODE,a.APOS_STRING_MODE,{begin:/as\s+\|/,
keywords:{keyword:"as"},end:/\|/,contains:[{begin:/\w+/}]},g,m,d],returnEnd:!0
},u=a.inherit(o,{className:"name",keywords:t,starts:a.inherit(b,{end:/\)/})})
;var h;d.contains=[u];const N=a.inherit(o,{keywords:t,className:"name",
starts:a.inherit(b,{end:/\}\}/})}),p=a.inherit(o,{keywords:t,className:"name"
}),E=a.inherit(o,{className:"name",keywords:t,starts:a.inherit(b,{end:/\}\}/})})
;return{name:"Handlebars",
aliases:["hbs","html.hbs","html.handlebars","htmlbars"],case_insensitive:!0,
subLanguage:"xml",contains:[{begin:/\\\{\{/,skip:!0},{begin:/\\\\(?=\{\{)/,
skip:!0},a.COMMENT(/\{\{!--/,/--\}\}/),a.COMMENT(/\{\{!/,/\}\}/),{
className:"template-tag",begin:/\{\{\{\{(?!\/)/,end:/\}\}\}\}/,contains:[N],
starts:{end:/\{\{\{\{\//,returnEnd:!0,subLanguage:"xml"}},{
className:"template-tag",begin:/\{\{\{\{\//,end:/\}\}\}\}/,contains:[p]},{
className:"template-tag",begin:/\{\{#/,end:/\}\}/,contains:[N]},{
className:"template-tag",begin:/\{\{(?=else\}\})/,end:/\}\}/,keywords:"else"},{
className:"template-tag",begin:/\{\{(?=else if)/,end:/\}\}/,keywords:"else if"
},{className:"template-tag",begin:/\{\{\//,end:/\}\}/,contains:[p]},{
className:"template-variable",begin:/\{\{\{/,end:/\}\}\}/,contains:[E]},{
className:"template-variable",begin:/\{\{/,end:/\}\}/,contains:[E]}]}}})());