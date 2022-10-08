/*! `protobuf` grammar compiled for Highlight.js 11.6.0 */
(()=>{var e=(()=>{"use strict";return e=>{const t={
match:[/(message|enum|service)\s+/,e.IDENT_RE],scope:{1:"keyword",
2:"title.class"}};return{name:"Protocol Buffers",keywords:{
keyword:["package","import","option","optional","required","repeated","group","oneof"],
type:["double","float","int32","int64","uint32","uint64","sint32","sint64","fixed32","fixed64","sfixed32","sfixed64","bool","string","bytes"],
literal:["true","false"]},
contains:[e.QUOTE_STRING_MODE,e.NUMBER_MODE,e.C_LINE_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE,t,{
className:"function",beginKeywords:"rpc",end:/[{;]/,excludeEnd:!0,
keywords:"rpc returns"},{begin:/^\s*[A-Z_]+(?=\s*=[^\n]+;$)/}]}}})()
;hljs.registerLanguage("protobuf",e)})();