hljs.registerLanguage("nestedtext",(()=>{"use strict";return t=>({
name:"Nested Text",aliases:["nt"],contains:[t.inherit(t.HASH_COMMENT_MODE,{
begin:/^\s*(?=#)/,excludeBegin:!0}),{variants:[{match:[/^\s*/,/-/,/[ ]/,/.*$/]
},{match:[/^\s*/,/-$/]}],className:{2:"bullet",4:"string"}},{
match:[/^\s*/,/>/,/[ ]/,/.*$/],className:{2:"punctuation",4:"string"}},{
match:[/^\s*(?=\S)/,/[^:]+/,/:\s*/,/$/],className:{2:"attribute",3:"punctuation"
}},{match:[/^\s*(?=\S)/,/[^:]*[^: ]/,/[ ]*:/,/[ ]/,/.*$/],className:{
2:"attribute",3:"punctuation",5:"string"}}]})})());