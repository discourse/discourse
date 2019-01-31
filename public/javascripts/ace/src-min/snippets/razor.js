define("ace/snippets/razor",["require","exports","module"],function(e,t,n){"use strict";t.snippetText="snippet if\n(${1} == ${2}) {\n	${3}\n}",t.scope="razor"});
                (function() {
                    window.require(["ace/snippets/razor"], function(m) {
                        if (typeof module == "object" && typeof exports == "object" && module) {
                            module.exports = m;
                        }
                    });
                })();
            