hljs.registerLanguage("erb",(()=>{"use strict";return e=>({name:"ERB",
subLanguage:"xml",contains:[e.COMMENT("<%#","%>"),{begin:"<%[%=-]?",
end:"[%-]?%>",subLanguage:"ruby",excludeBegin:!0,excludeEnd:!0}]})})());