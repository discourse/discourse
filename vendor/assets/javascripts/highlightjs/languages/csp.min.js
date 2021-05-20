hljs.registerLanguage("csp",(()=>{"use strict";return e=>({name:"CSP",
case_insensitive:!1,keywords:{$pattern:"[a-zA-Z][a-zA-Z0-9_-]*",
keyword:"base-uri child-src connect-src default-src font-src form-action frame-ancestors frame-src img-src media-src object-src plugin-types report-uri sandbox script-src style-src"
},contains:[{className:"string",begin:"'",end:"'"},{className:"attribute",
begin:"^Content",end:":",excludeEnd:!0}]})})());