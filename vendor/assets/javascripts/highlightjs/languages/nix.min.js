hljs.registerLanguage("nix",(()=>{"use strict";return e=>{const n={
keyword:"rec with let in inherit assert if else then",
literal:"true false or and null",
built_in:"import abort baseNameOf dirOf isNull builtins map removeAttrs throw toString derivation"
},i={className:"subst",begin:/\$\{/,end:/\}/,keywords:n},s={className:"string",
contains:[i],variants:[{begin:"''",end:"''"},{begin:'"',end:'"'}]
},t=[e.NUMBER_MODE,e.HASH_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE,s,{
begin:/[a-zA-Z0-9-_]+(\s*=)/,returnBegin:!0,relevance:0,contains:[{
className:"attr",begin:/\S+/}]}];return i.contains=t,{name:"Nix",
aliases:["nixos"],keywords:n,contains:t}}})());