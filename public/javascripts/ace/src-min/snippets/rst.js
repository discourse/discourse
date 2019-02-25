define("ace/snippets/rst",["require","exports","module"],function(e,t,n){"use strict";t.snippetText="# rst\n\nsnippet :\n	:${1:field name}: ${2:field body}\nsnippet *\n	*${1:Emphasis}*\nsnippet **\n	**${1:Strong emphasis}**\nsnippet _\n	\\`${1:hyperlink-name}\\`_\n	.. _\\`$1\\`: ${2:link-block}\nsnippet =\n	${1:Title}\n	=====${2:=}\n	${3}\nsnippet -\n	${1:Title}\n	-----${2:-}\n	${3}\nsnippet cont:\n	.. contents::\n	\n",t.scope="rst"});
                (function() {
                    window.require(["ace/snippets/rst"], function(m) {
                        if (typeof module == "object" && typeof exports == "object" && module) {
                            module.exports = m;
                        }
                    });
                })();
            