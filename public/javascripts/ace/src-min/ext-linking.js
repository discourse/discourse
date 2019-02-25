define("ace/ext/linking",["require","exports","module","ace/editor","ace/config"],function(e,t,n){function i(e){var n=e.editor,r=e.getAccelKey();if(r){var n=e.editor,i=e.getDocumentPosition(),s=n.session,o=s.getTokenAt(i.row,i.column);t.previousLinkingHover&&t.previousLinkingHover!=o&&n._emit("linkHoverOut"),n._emit("linkHover",{position:i,token:o}),t.previousLinkingHover=o}else t.previousLinkingHover&&(n._emit("linkHoverOut"),t.previousLinkingHover=!1)}function s(e){var t=e.getAccelKey(),n=e.getButton();if(n==0&&t){var r=e.editor,i=e.getDocumentPosition(),s=r.session,o=s.getTokenAt(i.row,i.column);r._emit("linkClick",{position:i,token:o})}}var r=e("ace/editor").Editor;e("../config").defineOptions(r.prototype,"editor",{enableLinking:{set:function(e){e?(this.on("click",s),this.on("mousemove",i)):(this.off("click",s),this.off("mousemove",i))},value:!1}}),t.previousLinkingHover=!1});
                (function() {
                    window.require(["ace/ext/linking"], function(m) {
                        if (typeof module == "object" && typeof exports == "object" && module) {
                            module.exports = m;
                        }
                    });
                })();
            