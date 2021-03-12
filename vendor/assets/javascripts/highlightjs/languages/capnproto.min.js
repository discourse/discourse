hljs.registerLanguage("capnproto",(()=>{"use strict";return n=>({
name:"Cap\u2019n Proto",aliases:["capnp"],keywords:{
keyword:"struct enum interface union group import using const annotation extends in of on as with from fixed",
built_in:"Void Bool Int8 Int16 Int32 Int64 UInt8 UInt16 UInt32 UInt64 Float32 Float64 Text Data AnyPointer AnyStruct Capability List",
literal:"true false"},
contains:[n.QUOTE_STRING_MODE,n.NUMBER_MODE,n.HASH_COMMENT_MODE,{
className:"meta",begin:/@0x[\w\d]{16};/,illegal:/\n/},{className:"symbol",
begin:/@\d+\b/},{className:"class",beginKeywords:"struct enum",end:/\{/,
illegal:/\n/,contains:[n.inherit(n.TITLE_MODE,{starts:{endsWithParent:!0,
excludeEnd:!0}})]},{className:"class",beginKeywords:"interface",end:/\{/,
illegal:/\n/,contains:[n.inherit(n.TITLE_MODE,{starts:{endsWithParent:!0,
excludeEnd:!0}})]}]})})());