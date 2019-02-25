define("ace/snippets/snippets",["require","exports","module"],function(e,t,n){"use strict";t.snippetText="# snippets for making snippets :)\nsnippet snip\n	snippet ${1:trigger}\n		${2}\nsnippet msnip\n	snippet ${1:trigger} ${2:description}\n		${3}\nsnippet v\n	{VISUAL}\n",t.scope="snippets"});
                (function() {
                    window.require(["ace/snippets/snippets"], function(m) {
                        if (typeof module == "object" && typeof exports == "object" && module) {
                            module.exports = m;
                        }
                    });
                })();
            