hljs.registerLanguage("scilab",(()=>{"use strict";return e=>{
const n=[e.C_NUMBER_MODE,{className:"string",begin:"'|\"",end:"'|\"",
contains:[e.BACKSLASH_ESCAPE,{begin:"''"}]}];return{name:"Scilab",
aliases:["sci"],keywords:{$pattern:/%?\w+/,
keyword:"abort break case clear catch continue do elseif else endfunction end for function global if pause return resume select try then while",
literal:"%f %F %t %T %pi %eps %inf %nan %e %i %z %s",
built_in:"abs and acos asin atan ceil cd chdir clearglobal cosh cos cumprod deff disp error exec execstr exists exp eye gettext floor fprintf fread fsolve imag isdef isempty isinfisnan isvector lasterror length load linspace list listfiles log10 log2 log max min msprintf mclose mopen ones or pathconvert poly printf prod pwd rand real round sinh sin size gsort sprintf sqrt strcat strcmps tring sum system tanh tan type typename warning zeros matrix"
},illegal:'("|#|/\\*|\\s+/\\w+)',contains:[{className:"function",
beginKeywords:"function",end:"$",contains:[e.UNDERSCORE_TITLE_MODE,{
className:"params",begin:"\\(",end:"\\)"}]},{
begin:"[a-zA-Z_][a-zA-Z_0-9]*[\\.']+",relevance:0},{begin:"\\[",
end:"\\][\\.']*",relevance:0,contains:n},e.COMMENT("//","$")].concat(n)}}})());