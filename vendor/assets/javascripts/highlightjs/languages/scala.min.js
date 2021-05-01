hljs.registerLanguage("scala",(()=>{"use strict";return e=>{const n={
className:"subst",variants:[{begin:"\\$[A-Za-z0-9_]+"},{begin:/\$\{/,end:/\}/}]
},a={className:"string",variants:[{begin:'"""',end:'"""'},{begin:'"',end:'"',
illegal:"\\n",contains:[e.BACKSLASH_ESCAPE]},{begin:'[a-z]+"',end:'"',
illegal:"\\n",contains:[e.BACKSLASH_ESCAPE,n]},{className:"string",
begin:'[a-z]+"""',end:'"""',contains:[n],relevance:10}]},s={className:"type",
begin:"\\b[A-Z][A-Za-z0-9_]*",relevance:0},t={className:"title",
begin:/[^0-9\n\t "'(),.`{}\[\]:;][^\n\t "'(),.`{}\[\]:;]+|[^0-9\n\t "'(),.`{}\[\]:;=]/,
relevance:0},i={className:"class",beginKeywords:"class object trait type",
end:/[:={\[\n;]/,excludeEnd:!0,
contains:[e.C_LINE_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE,{
beginKeywords:"extends with",relevance:10},{begin:/\[/,end:/\]/,excludeBegin:!0,
excludeEnd:!0,relevance:0,contains:[s]},{className:"params",begin:/\(/,end:/\)/,
excludeBegin:!0,excludeEnd:!0,relevance:0,contains:[s]},t]},l={
className:"function",beginKeywords:"def",end:/[:={\[(\n;]/,excludeEnd:!0,
contains:[t]};return{name:"Scala",keywords:{literal:"true false null",
keyword:"type yield lazy override def with val var sealed abstract private trait object if forSome for while throw finally protected extends import final return else break new catch super class case package default try this match continue throws implicit"
},contains:[e.C_LINE_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE,a,{className:"symbol",
begin:"'\\w[\\w\\d_]*(?!')"},s,l,i,e.C_NUMBER_MODE,{className:"meta",
begin:"@[A-Za-z]+"}]}}})());