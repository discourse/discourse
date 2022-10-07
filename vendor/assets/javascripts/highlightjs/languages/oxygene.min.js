/*! `oxygene` grammar compiled for Highlight.js 11.6.0 */
(()=>{var e=(()=>{"use strict";return e=>{const t={$pattern:/\.?\w+/,
keyword:"abstract add and array as asc aspect assembly async begin break block by case class concat const copy constructor continue create default delegate desc distinct div do downto dynamic each else empty end ensure enum equals event except exit extension external false final finalize finalizer finally flags for forward from function future global group has if implementation implements implies in index inherited inline interface into invariants is iterator join locked locking loop matching method mod module namespace nested new nil not notify nullable of old on operator or order out override parallel params partial pinned private procedure property protected public queryable raise read readonly record reintroduce remove repeat require result reverse sealed select self sequence set shl shr skip static step soft take then to true try tuple type union unit unsafe until uses using var virtual raises volatile where while with write xor yield await mapped deprecated stdcall cdecl pascal register safecall overload library platform reference packed strict published autoreleasepool selector strong weak unretained"
},r=e.COMMENT(/\{/,/\}/,{relevance:0}),n=e.COMMENT("\\(\\*","\\*\\)",{
relevance:10}),a={className:"string",begin:"'",end:"'",contains:[{begin:"''"}]
},i={className:"string",begin:"(#\\d+)+"},s={
beginKeywords:"function constructor destructor procedure method",end:"[:;]",
keywords:"function constructor|10 destructor|10 procedure|10 method|10",
contains:[e.inherit(e.TITLE_MODE,{scope:"title.function"}),{className:"params",
begin:"\\(",end:"\\)",keywords:t,contains:[a,i]},r,n]};return{name:"Oxygene",
case_insensitive:!0,keywords:t,illegal:'("|\\$[G-Zg-z]|\\/\\*|</|=>|->)',
contains:[r,n,e.C_LINE_COMMENT_MODE,a,i,e.NUMBER_MODE,s,{scope:"punctuation",
match:/;/,relevance:0}]}}})();hljs.registerLanguage("oxygene",e)})();