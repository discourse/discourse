hljs.registerLanguage("oxygene",(()=>{"use strict";return e=>{const n={
$pattern:/\.?\w+/,
keyword:"abstract add and array as asc aspect assembly async begin break block by case class concat const copy constructor continue create default delegate desc distinct div do downto dynamic each else empty end ensure enum equals event except exit extension external false final finalize finalizer finally flags for forward from function future global group has if implementation implements implies in index inherited inline interface into invariants is iterator join locked locking loop matching method mod module namespace nested new nil not notify nullable of old on operator or order out override parallel params partial pinned private procedure property protected public queryable raise read readonly record reintroduce remove repeat require result reverse sealed select self sequence set shl shr skip static step soft take then to true try tuple type union unit unsafe until uses using var virtual raises volatile where while with write xor yield await mapped deprecated stdcall cdecl pascal register safecall overload library platform reference packed strict published autoreleasepool selector strong weak unretained"
},r=e.COMMENT(/\{/,/\}/,{relevance:0}),a=e.COMMENT("\\(\\*","\\*\\)",{
relevance:10}),t={className:"string",begin:"'",end:"'",contains:[{begin:"''"}]
},s={className:"string",begin:"(#\\d+)+"},i={className:"function",
beginKeywords:"function constructor destructor procedure method",end:"[:;]",
keywords:"function constructor|10 destructor|10 procedure|10 method|10",
contains:[e.TITLE_MODE,{className:"params",begin:"\\(",end:"\\)",keywords:n,
contains:[t,s]},r,a]};return{name:"Oxygene",case_insensitive:!0,keywords:n,
illegal:'("|\\$[G-Zg-z]|\\/\\*|</|=>|->)',
contains:[r,a,e.C_LINE_COMMENT_MODE,t,s,e.NUMBER_MODE,i,{className:"class",
begin:"=\\bclass\\b",end:"end;",keywords:n,
contains:[t,s,r,a,e.C_LINE_COMMENT_MODE,i]}]}}})());