hljs.registerLanguage("monkey",(()=>{"use strict";return e=>{const n={
className:"number",relevance:0,variants:[{begin:"[$][a-fA-F0-9]+"
},e.NUMBER_MODE]};return{name:"Monkey",case_insensitive:!0,keywords:{
keyword:"public private property continue exit extern new try catch eachin not abstract final select case default const local global field end if then else elseif endif while wend repeat until forever for to step next return module inline throw import",
built_in:"DebugLog DebugStop Error Print ACos ACosr ASin ASinr ATan ATan2 ATan2r ATanr Abs Abs Ceil Clamp Clamp Cos Cosr Exp Floor Log Max Max Min Min Pow Sgn Sgn Sin Sinr Sqrt Tan Tanr Seed PI HALFPI TWOPI",
literal:"true false null and or shl shr mod"},illegal:/\/\*/,
contains:[e.COMMENT("#rem","#end"),e.COMMENT("'","$",{relevance:0}),{
className:"function",beginKeywords:"function method",end:"[(=:]|$",illegal:/\n/,
contains:[e.UNDERSCORE_TITLE_MODE]},{className:"class",
beginKeywords:"class interface",end:"$",contains:[{
beginKeywords:"extends implements"},e.UNDERSCORE_TITLE_MODE]},{
className:"built_in",begin:"\\b(self|super)\\b"},{className:"meta",
begin:"\\s*#",end:"$",keywords:{keyword:"if else elseif endif end then"}},{
className:"meta",begin:"^\\s*strict\\b"},{beginKeywords:"alias",end:"=",
contains:[e.UNDERSCORE_TITLE_MODE]},e.QUOTE_STRING_MODE,n]}}})());