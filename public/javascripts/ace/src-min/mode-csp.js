define("ace/mode/csp_highlight_rules",["require","exports","module","ace/lib/oop","ace/mode/text_highlight_rules"],function(e,t,n){"use strict";var r=e("../lib/oop"),i=e("./text_highlight_rules").TextHighlightRules,s=function(){var e=this.createKeywordMapper({"constant.language":"child-src|connect-src|default-src|font-src|frame-src|img-src|manifest-src|media-src|object-src|script-src|style-src|worker-src|base-uri|plugin-types|sandbox|disown-opener|form-action|frame-ancestors|report-uri|report-to|upgrade-insecure-requests|block-all-mixed-content|require-sri-for|reflected-xss|referrer|policy-uri",variable:"'none'|'self'|'unsafe-inline'|'unsafe-eval'|'strict-dynamic'|'unsafe-hashed-attributes'"},"identifier",!0);this.$rules={start:[{token:"string.link",regex:/https?:[^;\s]*/},{token:"operator.punctuation",regex:/;/},{token:e,regex:/[^\s;]+/}]}};r.inherits(s,i),t.CspHighlightRules=s}),define("ace/mode/csp",["require","exports","module","ace/mode/text","ace/mode/csp_highlight_rules","ace/lib/oop"],function(e,t,n){"use strict";var r=e("./text").Mode,i=e("./csp_highlight_rules").CspHighlightRules,s=e("../lib/oop"),o=function(){this.HighlightRules=i};s.inherits(o,r),function(){this.$id="ace/mode/csp"}.call(o.prototype),t.Mode=o});
                (function() {
                    window.require(["ace/mode/csp"], function(m) {
                        if (typeof module == "object" && typeof exports == "object" && module) {
                            module.exports = m;
                        }
                    });
                })();
            