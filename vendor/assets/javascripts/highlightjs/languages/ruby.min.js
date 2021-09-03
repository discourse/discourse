hljs.registerLanguage("ruby",(()=>{"use strict";function e(e){
return n("(?=",e,")")}function n(...e){return e.map((e=>{
return(n=e)?"string"==typeof n?n:n.source:null;var n})).join("")}return a=>{
const i="([a-zA-Z_]\\w*[!?=]?|[-+~]@|<<|>>|=~|===?|<=>|[<>]=?|\\*\\*|[-/+%^&*~`|]|\\[\\]=?)",s={
keyword:"and then defined module in return redo if BEGIN retry end for self when next until do begin unless END rescue else break undef not super class case require yield alias while ensure elsif or include attr_reader attr_writer attr_accessor __FILE__",
built_in:"proc lambda",literal:"true false nil"},r={className:"doctag",
begin:"@[A-Za-z]+"},b={begin:"#<",end:">"},c=[a.COMMENT("#","$",{contains:[r]
}),a.COMMENT("^=begin","^=end",{contains:[r],relevance:10
}),a.COMMENT("^__END__","\\n$")],t={className:"subst",begin:/#\{/,end:/\}/,
keywords:s},g={className:"string",contains:[a.BACKSLASH_ESCAPE,t],variants:[{
begin:/'/,end:/'/},{begin:/"/,end:/"/},{begin:/`/,end:/`/},{begin:/%[qQwWx]?\(/,
end:/\)/},{begin:/%[qQwWx]?\[/,end:/\]/},{begin:/%[qQwWx]?\{/,end:/\}/},{
begin:/%[qQwWx]?</,end:/>/},{begin:/%[qQwWx]?\//,end:/\//},{begin:/%[qQwWx]?%/,
end:/%/},{begin:/%[qQwWx]?-/,end:/-/},{begin:/%[qQwWx]?\|/,end:/\|/},{
begin:/\B\?(\\\d{1,3})/},{begin:/\B\?(\\x[A-Fa-f0-9]{1,2})/},{
begin:/\B\?(\\u\{?[A-Fa-f0-9]{1,6}\}?)/},{
begin:/\B\?(\\M-\\C-|\\M-\\c|\\c\\M-|\\M-|\\C-\\M-)[\x20-\x7e]/},{
begin:/\B\?\\(c|C-)[\x20-\x7e]/},{begin:/\B\?\\?\S/},{
begin:n(/<<[-~]?'?/,e(/(\w+)(?=\W)[^\n]*\n(?:[^\n]*\n)*?\s*\1\b/)),
contains:[a.END_SAME_AS_BEGIN({begin:/(\w+)/,end:/(\w+)/,
contains:[a.BACKSLASH_ESCAPE,t]})]}]},d="[0-9](_?[0-9])*",l={className:"number",
relevance:0,variants:[{
begin:`\\b([1-9](_?[0-9])*|0)(\\.(${d}))?([eE][+-]?(${d})|r)?i?\\b`},{
begin:"\\b0[dD][0-9](_?[0-9])*r?i?\\b"},{begin:"\\b0[bB][0-1](_?[0-1])*r?i?\\b"
},{begin:"\\b0[oO][0-7](_?[0-7])*r?i?\\b"},{
begin:"\\b0[xX][0-9a-fA-F](_?[0-9a-fA-F])*r?i?\\b"},{
begin:"\\b0(_?[0-7])+r?i?\\b"}]},o={className:"params",begin:"\\(",end:"\\)",
endsParent:!0,keywords:s},_=[g,{className:"class",beginKeywords:"class module",
end:"$|;",illegal:/=/,contains:[a.inherit(a.TITLE_MODE,{
begin:"[A-Za-z_]\\w*(::\\w+)*(\\?|!)?"}),{begin:"<\\s*",contains:[{
begin:"("+a.IDENT_RE+"::)?"+a.IDENT_RE,relevance:0}]}].concat(c)},{
className:"function",begin:n(/def\s+/,e(i+"\\s*(\\(|;|$)")),relevance:0,
keywords:"def",end:"$|;",contains:[a.inherit(a.TITLE_MODE,{begin:i
}),o].concat(c)},{begin:a.IDENT_RE+"::"},{className:"symbol",
begin:a.UNDERSCORE_IDENT_RE+"(!|\\?)?:",relevance:0},{className:"symbol",
begin:":(?!\\s)",contains:[g,{begin:i}],relevance:0},l,{className:"variable",
begin:"(\\$\\W)|((\\$|@@?)(\\w+))(?=[^@$?])(?![A-Za-z])(?![@$?'])"},{
className:"params",begin:/\|/,end:/\|/,relevance:0,keywords:s},{
begin:"("+a.RE_STARTERS_RE+"|unless)\\s*",keywords:"unless",contains:[{
className:"regexp",contains:[a.BACKSLASH_ESCAPE,t],illegal:/\n/,variants:[{
begin:"/",end:"/[a-z]*"},{begin:/%r\{/,end:/\}[a-z]*/},{begin:"%r\\(",
end:"\\)[a-z]*"},{begin:"%r!",end:"![a-z]*"},{begin:"%r\\[",end:"\\][a-z]*"}]
}].concat(b,c),relevance:0}].concat(b,c);t.contains=_,o.contains=_;const E=[{
begin:/^\s*=>/,starts:{end:"$",contains:_}},{className:"meta",
begin:"^([>?]>|[\\w#]+\\(\\w+\\):\\d+:\\d+>|(\\w+-)?\\d+\\.\\d+\\.\\d+(p\\d+)?[^\\d][^>]+>)(?=[ ])",
starts:{end:"$",contains:_}}];return c.unshift(b),{name:"Ruby",
aliases:["rb","gemspec","podspec","thor","irb"],keywords:s,illegal:/\/\*/,
contains:[a.SHEBANG({binary:"ruby"})].concat(E).concat(c).concat(_)}}})());