hljs.registerLanguage("taggerscript",(()=>{"use strict";return e=>({
name:"Tagger Script",contains:[{className:"comment",begin:/\$noop\(/,end:/\)/,
contains:[{begin:/\(/,end:/\)/,contains:["self",{begin:/\\./}]}],relevance:10},{
className:"keyword",begin:/\$(?!noop)[a-zA-Z][_a-zA-Z0-9]*/,end:/\(/,
excludeEnd:!0},{className:"variable",begin:/%[_a-zA-Z0-9:]*/,end:"%"},{
className:"symbol",begin:/\\./}]})})());