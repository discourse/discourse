hljs.registerLanguage("ldif",(()=>{"use strict";return e=>({name:"LDIF",
contains:[{className:"attribute",begin:"^dn",end:": ",excludeEnd:!0,starts:{
end:"$",relevance:0},relevance:10},{className:"attribute",begin:"^\\w",end:": ",
excludeEnd:!0,starts:{end:"$",relevance:0}},{className:"literal",begin:"^-",
end:"$"},e.HASH_COMMENT_MODE]})})());