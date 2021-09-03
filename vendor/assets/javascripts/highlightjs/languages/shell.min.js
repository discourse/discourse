hljs.registerLanguage("shell",(()=>{"use strict";return s=>({
name:"Shell Session",aliases:["console","shellsession"],contains:[{
className:"meta",begin:/^\s{0,3}[/~\w\d[\]()@-]*[>%$#][ ]?/,starts:{
end:/[^\\](?=\s*$)/,subLanguage:"bash"}}]})})());