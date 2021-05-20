hljs.registerLanguage("ebnf",(()=>{"use strict";return e=>{
const a=e.COMMENT(/\(\*/,/\*\)/);return{name:"Extended Backus-Naur Form",
illegal:/\S/,contains:[a,{className:"attribute",
begin:/^[ ]*[a-zA-Z]+([\s_-]+[a-zA-Z]+)*/},{begin:/=/,end:/[.;]/,contains:[a,{
className:"meta",begin:/\?.*\?/},{className:"string",
variants:[e.APOS_STRING_MODE,e.QUOTE_STRING_MODE,{begin:"`",end:"`"}]}]}]}}
})());