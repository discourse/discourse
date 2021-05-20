hljs.registerLanguage("dart",(()=>{"use strict";return e=>{const n={
className:"subst",variants:[{begin:"\\$[A-Za-z0-9_]+"}]},a={className:"subst",
variants:[{begin:/\$\{/,end:/\}/}],keywords:"true false null this is new super"
},t={className:"string",variants:[{begin:"r'''",end:"'''"},{begin:'r"""',
end:'"""'},{begin:"r'",end:"'",illegal:"\\n"},{begin:'r"',end:'"',illegal:"\\n"
},{begin:"'''",end:"'''",contains:[e.BACKSLASH_ESCAPE,n,a]},{begin:'"""',
end:'"""',contains:[e.BACKSLASH_ESCAPE,n,a]},{begin:"'",end:"'",illegal:"\\n",
contains:[e.BACKSLASH_ESCAPE,n,a]},{begin:'"',end:'"',illegal:"\\n",
contains:[e.BACKSLASH_ESCAPE,n,a]}]};a.contains=[e.C_NUMBER_MODE,t]
;const i=["Comparable","DateTime","Duration","Function","Iterable","Iterator","List","Map","Match","Object","Pattern","RegExp","Set","Stopwatch","String","StringBuffer","StringSink","Symbol","Type","Uri","bool","double","int","num","Element","ElementList"],r=i.map((e=>e+"?"))
;return{name:"Dart",keywords:{
keyword:"abstract as assert async await break case catch class const continue covariant default deferred do dynamic else enum export extends extension external factory false final finally for Function get hide if implements import in inferface is late library mixin new null on operator part required rethrow return set show static super switch sync this throw true try typedef var void while with yield",
built_in:i.concat(r).concat(["Never","Null","dynamic","print","document","querySelector","querySelectorAll","window"]),
$pattern:/[A-Za-z][A-Za-z0-9_]*\??/},
contains:[t,e.COMMENT(/\/\*\*(?!\/)/,/\*\//,{subLanguage:"markdown",relevance:0
}),e.COMMENT(/\/{3,} ?/,/$/,{contains:[{subLanguage:"markdown",begin:".",
end:"$",relevance:0}]}),e.C_LINE_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE,{
className:"class",beginKeywords:"class interface",end:/\{/,excludeEnd:!0,
contains:[{beginKeywords:"extends implements"},e.UNDERSCORE_TITLE_MODE]
},e.C_NUMBER_MODE,{className:"meta",begin:"@[A-Za-z]+"},{begin:"=>"}]}}})());