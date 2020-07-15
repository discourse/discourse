import Component from "@ember/component";
import { highlightText } from "discourse/lib/highlight-syntax";
import { escapeExpression } from "discourse/lib/utilities";
import discourseComputed from "discourse-common/utils/decorators";
import { htmlSafe } from "@ember/template";

export default Component.extend({
  didReceiveAttrs() {
    this._super(...arguments);
    if (this.code === this.previousCode) return;

    this.set("previousCode", this.code);
    this.set("highlightResult", null);
    const toHighlight = this.code;
    highlightText(escapeExpression(toHighlight), this.lang).then(
      ({ result }) => {
        if (toHighlight !== this.code) return; // Code has changed since highlight was requested
        this.set("highlightResult", result);
      }
    );
  },

  @discourseComputed("code", "highlightResult")
  displayCode(code, highlightResult) {
    if (highlightResult) return htmlSafe(highlightResult);
    return code;
  },

  @discourseComputed("highlightResult", "lang")
  codeClasses(highlightResult, lang) {
    const classes = [];
    if (lang) classes.push(lang);
    if (highlightResult) classes.push("hljs");

    return classes.join(" ");
  }
});
