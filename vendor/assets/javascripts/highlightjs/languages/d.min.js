/*! `d` grammar compiled for Highlight.js 11.6.0 */
(()=>{var e=(()=>{"use strict";return e=>{const a={
$pattern:e.UNDERSCORE_IDENT_RE,
keyword:"abstract alias align asm assert auto body break byte case cast catch class const continue debug default delete deprecated do else enum export extern final finally for foreach foreach_reverse|10 goto if immutable import in inout int interface invariant is lazy macro mixin module new nothrow out override package pragma private protected public pure ref return scope shared static struct super switch synchronized template this throw try typedef typeid typeof union unittest version void volatile while with __FILE__ __LINE__ __gshared|10 __thread __traits __DATE__ __EOF__ __TIME__ __TIMESTAMP__ __VENDOR__ __VERSION__",
built_in:"bool cdouble cent cfloat char creal dchar delegate double dstring float function idouble ifloat ireal long real short string ubyte ucent uint ulong ushort wchar wstring",
literal:"false null true"
},d="((0|[1-9][\\d_]*)|0[bB][01_]+|0[xX]([\\da-fA-F][\\da-fA-F_]*|_[\\da-fA-F][\\da-fA-F_]*))",n="\\\\(['\"\\?\\\\abfnrtv]|u[\\dA-Fa-f]{4}|[0-7]{1,3}|x[\\dA-Fa-f]{2}|U[\\dA-Fa-f]{8})|&[a-zA-Z\\d]{2,};",t={
className:"number",begin:"\\b"+d+"(L|u|U|Lu|LU|uL|UL)?",relevance:0},_={
className:"number",
begin:"\\b(((0[xX](([\\da-fA-F][\\da-fA-F_]*|_[\\da-fA-F][\\da-fA-F_]*)\\.([\\da-fA-F][\\da-fA-F_]*|_[\\da-fA-F][\\da-fA-F_]*)|\\.?([\\da-fA-F][\\da-fA-F_]*|_[\\da-fA-F][\\da-fA-F_]*))[pP][+-]?(0|[1-9][\\d_]*|\\d[\\d_]*|[\\d_]+?\\d))|((0|[1-9][\\d_]*|\\d[\\d_]*|[\\d_]+?\\d)(\\.\\d*|([eE][+-]?(0|[1-9][\\d_]*|\\d[\\d_]*|[\\d_]+?\\d)))|\\d+\\.(0|[1-9][\\d_]*|\\d[\\d_]*|[\\d_]+?\\d)|\\.(0|[1-9][\\d_]*)([eE][+-]?(0|[1-9][\\d_]*|\\d[\\d_]*|[\\d_]+?\\d))?))([fF]|L|i|[fF]i|Li)?|"+d+"(i|[fF]i|Li))",
relevance:0},r={className:"string",begin:"'("+n+"|.)",end:"'",illegal:"."},i={
className:"string",begin:'"',contains:[{begin:n,relevance:0}],end:'"[cwd]?'
},s=e.COMMENT("\\/\\+","\\+\\/",{contains:["self"],relevance:10});return{
name:"D",keywords:a,contains:[e.C_LINE_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE,s,{
className:"string",begin:'x"[\\da-fA-F\\s\\n\\r]*"[cwd]?',relevance:10},i,{
className:"string",begin:'[rq]"',end:'"[cwd]?',relevance:5},{className:"string",
begin:"`",end:"`[cwd]?"},{className:"string",begin:'q"\\{',end:'\\}"'},_,t,r,{
className:"meta",begin:"^#!",end:"$",relevance:5},{className:"meta",
begin:"#(line)",end:"$",relevance:5},{className:"keyword",
begin:"@[a-zA-Z_][a-zA-Z_\\d]*"}]}}})();hljs.registerLanguage("d",e)})();