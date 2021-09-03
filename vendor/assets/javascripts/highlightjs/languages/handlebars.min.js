hljs.registerLanguage("handlebars",(()=>{"use strict";function e(e){
return e?"string"==typeof e?e:e.source:null}function n(...n){
return n.map((n=>e(n))).join("")}return t=>{const a={$pattern:/[\w.\/]+/,
built_in:["action","bindattr","collection","component","concat","debugger","each","each-in","get","hash","if","in","input","link-to","loc","log","lookup","mut","outlet","partial","query-params","render","template","textarea","unbound","unless","view","with","yield"]
},s=/\[\]|\[[^\]]+\]/,i=/[^\s!"#%&'()*+,.\/;<=>@\[\\\]^`{|}~]+/,r=function(...n){
return"("+((e=>{const n=e[e.length-1]
;return"object"==typeof n&&n.constructor===Object?(e.splice(e.length-1,1),n):{}
})(n).capture?"":"?:")+n.map((n=>e(n))).join("|")+")"
}(/""|"[^"]+"/,/''|'[^']+'/,s,i),l=n(n("(?:",/\.|\.\/|\//,")?"),r,(p=n(/(\.|\/)/,r),
n("(?:",p,")*"))),c=n("(",s,"|",i,")(?==)"),o={begin:l},m=t.inherit(o,{
keywords:{$pattern:/[\w.\/]+/,literal:["true","false","undefined","null"]}}),d={
begin:/\(/,end:/\)/},g={className:"attr",begin:c,relevance:0,starts:{begin:/=/,
end:/=/,starts:{
contains:[t.NUMBER_MODE,t.QUOTE_STRING_MODE,t.APOS_STRING_MODE,m,d]}}},u={
contains:[t.NUMBER_MODE,t.QUOTE_STRING_MODE,t.APOS_STRING_MODE,{begin:/as\s+\|/,
keywords:{keyword:"as"},end:/\|/,contains:[{begin:/\w+/}]},g,m,d],returnEnd:!0
},b=t.inherit(o,{className:"name",keywords:a,starts:t.inherit(u,{end:/\)/})})
;var p;d.contains=[b];const h=t.inherit(o,{keywords:a,className:"name",
starts:t.inherit(u,{end:/\}\}/})}),N=t.inherit(o,{keywords:a,className:"name"
}),w=t.inherit(o,{className:"name",keywords:a,starts:t.inherit(u,{end:/\}\}/})})
;return{name:"Handlebars",
aliases:["hbs","html.hbs","html.handlebars","htmlbars"],case_insensitive:!0,
subLanguage:"xml",contains:[{begin:/\\\{\{/,skip:!0},{begin:/\\\\(?=\{\{)/,
skip:!0},t.COMMENT(/\{\{!--/,/--\}\}/),t.COMMENT(/\{\{!/,/\}\}/),{
className:"template-tag",begin:/\{\{\{\{(?!\/)/,end:/\}\}\}\}/,contains:[h],
starts:{end:/\{\{\{\{\//,returnEnd:!0,subLanguage:"xml"}},{
className:"template-tag",begin:/\{\{\{\{\//,end:/\}\}\}\}/,contains:[N]},{
className:"template-tag",begin:/\{\{#/,end:/\}\}/,contains:[h]},{
className:"template-tag",begin:/\{\{(?=else\}\})/,end:/\}\}/,keywords:"else"},{
className:"template-tag",begin:/\{\{(?=else if)/,end:/\}\}/,keywords:"else if"
},{className:"template-tag",begin:/\{\{\//,end:/\}\}/,contains:[N]},{
className:"template-variable",begin:/\{\{\{/,end:/\}\}\}/,contains:[w]},{
className:"template-variable",begin:/\{\{/,end:/\}\}/,contains:[w]}]}}})());