hljs.registerLanguage("fsharp",(()=>{"use strict";return e=>{const n={begin:"<",
end:">",contains:[e.inherit(e.TITLE_MODE,{begin:/'[a-zA-Z0-9_]+/})]};return{
name:"F#",aliases:["fs"],
keywords:["abstract","and","as","assert","base","begin","class","default","delegate","do","done","downcast","downto","elif","else","end","exception","extern","false","finally","for","fun","function","global","if","in","inherit","inline","interface","internal","lazy","let","match","member","module","mutable","namespace","new","null","of","open","or","override","private","public","rec","return","sig","static","struct","then","to","true","try","type","upcast","use","val","void","when","while","with","yield"],
illegal:/\/\*/,contains:[{className:"keyword",begin:/\b(yield|return|let|do)!/
},{className:"string",begin:'@"',end:'"',contains:[{begin:'""'}]},{
className:"string",begin:'"""',end:'"""'},e.COMMENT("\\(\\*(\\s)","\\*\\)",{
contains:["self"]}),{className:"class",beginKeywords:"type",end:"\\(|=|$",
excludeEnd:!0,contains:[e.UNDERSCORE_TITLE_MODE,n]},{className:"meta",
begin:"\\[<",end:">\\]",relevance:10},{className:"symbol",
begin:"\\B('[A-Za-z])\\b",contains:[e.BACKSLASH_ESCAPE]
},e.C_LINE_COMMENT_MODE,e.inherit(e.QUOTE_STRING_MODE,{illegal:null
}),e.C_NUMBER_MODE]}}})());