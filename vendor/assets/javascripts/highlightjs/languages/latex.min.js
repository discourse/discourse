hljs.registerLanguage("latex",(()=>{"use strict";function e(...e){
return"("+((e=>{const n=e[e.length-1]
;return"object"==typeof n&&n.constructor===Object?(e.splice(e.length-1,1),n):{}
})(e).capture?"":"?:")+e.map((e=>{return(n=e)?"string"==typeof n?n:n.source:null
;var n})).join("|")+")"}return n=>{const a=[{begin:/\^{6}[0-9a-f]{6}/},{
begin:/\^{5}[0-9a-f]{5}/},{begin:/\^{4}[0-9a-f]{4}/},{begin:/\^{3}[0-9a-f]{3}/
},{begin:/\^{2}[0-9a-f]{2}/},{begin:/\^{2}[\u0000-\u007f]/}],t=[{
className:"keyword",begin:/\\/,relevance:0,contains:[{endsParent:!0,
begin:e(...["(?:NeedsTeXFormat|RequirePackage|GetIdInfo)","Provides(?:Expl)?(?:Package|Class|File)","(?:DeclareOption|ProcessOptions)","(?:documentclass|usepackage|input|include)","makeat(?:letter|other)","ExplSyntax(?:On|Off)","(?:new|renew|provide)?command","(?:re)newenvironment","(?:New|Renew|Provide|Declare)(?:Expandable)?DocumentCommand","(?:New|Renew|Provide|Declare)DocumentEnvironment","(?:(?:e|g|x)?def|let)","(?:begin|end)","(?:part|chapter|(?:sub){0,2}section|(?:sub)?paragraph)","caption","(?:label|(?:eq|page|name)?ref|(?:paren|foot|super)?cite)","(?:alpha|beta|[Gg]amma|[Dd]elta|(?:var)?epsilon|zeta|eta|[Tt]heta|vartheta)","(?:iota|(?:var)?kappa|[Ll]ambda|mu|nu|[Xx]i|[Pp]i|varpi|(?:var)rho)","(?:[Ss]igma|varsigma|tau|[Uu]psilon|[Pp]hi|varphi|chi|[Pp]si|[Oo]mega)","(?:frac|sum|prod|lim|infty|times|sqrt|leq|geq|left|right|middle|[bB]igg?)","(?:[lr]angle|q?quad|[lcvdi]?dots|d?dot|hat|tilde|bar)"].map((e=>e+"(?![a-zA-Z@:_])")))
},{endsParent:!0,
begin:RegExp(["(?:__)?[a-zA-Z]{2,}_[a-zA-Z](?:_?[a-zA-Z])+:[a-zA-Z]*","[lgc]__?[a-zA-Z](?:_?[a-zA-Z])*_[a-zA-Z]{2,}","[qs]__?[a-zA-Z](?:_?[a-zA-Z])+","use(?:_i)?:[a-zA-Z]*","(?:else|fi|or):","(?:if|cs|exp):w","(?:hbox|vbox):n","::[a-zA-Z]_unbraced","::[a-zA-Z:]"].map((e=>e+"(?![a-zA-Z:_])")).join("|"))
},{endsParent:!0,variants:a},{endsParent:!0,relevance:0,variants:[{
begin:/[a-zA-Z@]+/},{begin:/[^a-zA-Z@]?/}]}]},{className:"params",relevance:0,
begin:/#+\d?/},{variants:a},{className:"built_in",relevance:0,begin:/[$&^_]/},{
className:"meta",begin:/% ?!(T[eE]X|tex|BIB|bib)/,end:"$",relevance:10
},n.COMMENT("%","$",{relevance:0})],i={begin:/\{/,end:/\}/,relevance:0,
contains:["self",...t]},r=n.inherit(i,{relevance:0,endsParent:!0,
contains:[i,...t]}),s={begin:/\[/,end:/\]/,endsParent:!0,relevance:0,
contains:[i,...t]},c={begin:/\s+/,relevance:0},l=[r],o=[s],d=(e,n)=>({
contains:[c],starts:{relevance:0,contains:e,starts:n}}),g=(e,n)=>({
begin:"\\\\"+e+"(?![a-zA-Z@:_])",keywords:{$pattern:/\\[a-zA-Z]+/,keyword:"\\"+e
},relevance:0,contains:[c],starts:n}),m=(e,a)=>n.inherit({
begin:"\\\\begin(?=[ \t]*(\\r?\\n[ \t]*)?\\{"+e+"\\})",keywords:{
$pattern:/\\[a-zA-Z]+/,keyword:"\\begin"},relevance:0
},d(l,a)),b=(e="string")=>n.END_SAME_AS_BEGIN({className:e,begin:/(.|\r?\n)/,
end:/(.|\r?\n)/,excludeBegin:!0,excludeEnd:!0,endsParent:!0}),p=e=>({
className:"string",end:"(?=\\\\end\\{"+e+"\\})"}),v=(e="string")=>({relevance:0,
begin:/\{/,starts:{endsParent:!0,contains:[{className:e,end:/(?=\})/,
endsParent:!0,contains:[{begin:/\{/,end:/\}/,relevance:0,contains:["self"]}]}]}
});return{name:"LaTeX",aliases:["tex"],
contains:[...["verb","lstinline"].map((e=>g(e,{contains:[b()]}))),g("mint",d(l,{
contains:[b()]})),g("mintinline",d(l,{contains:[v(),b()]})),g("url",{
contains:[v("link"),v("link")]}),g("hyperref",{contains:[v("link")]
}),g("href",d(o,{contains:[v("link")]
})),...[].concat(...["","\\*"].map((e=>[m("verbatim"+e,p("verbatim"+e)),m("filecontents"+e,d(l,p("filecontents"+e))),...["","B","L"].map((n=>m(n+"Verbatim"+e,d(o,p(n+"Verbatim"+e)))))]))),m("minted",d(o,d(l,p("minted")))),...t]
}}})());