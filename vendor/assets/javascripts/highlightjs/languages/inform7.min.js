/*! `inform7` grammar compiled for Highlight.js 11.6.0 */
(()=>{var e=(()=>{"use strict";return e=>({name:"Inform 7",aliases:["i7"],
case_insensitive:!0,keywords:{
keyword:"thing room person man woman animal container supporter backdrop door scenery open closed locked inside gender is are say understand kind of rule"
},contains:[{className:"string",begin:'"',end:'"',relevance:0,contains:[{
className:"subst",begin:"\\[",end:"\\]"}]},{className:"section",
begin:/^(Volume|Book|Part|Chapter|Section|Table)\b/,end:"$"},{
begin:/^(Check|Carry out|Report|Instead of|To|Rule|When|Before|After)\b/,
end:":",contains:[{begin:"\\(This",end:"\\)"}]},{className:"comment",
begin:"\\[",end:"\\]",contains:["self"]}]})})()
;hljs.registerLanguage("inform7",e)})();