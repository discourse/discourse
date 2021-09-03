hljs.registerLanguage("ldif",(()=>{"use strict";return a=>({name:"LDIF",
contains:[{className:"attribute",match:"^dn(?=:)",relevance:10},{
className:"attribute",match:"^\\w+(?=:)"},{className:"literal",match:"^-"
},a.HASH_COMMENT_MODE]})})());