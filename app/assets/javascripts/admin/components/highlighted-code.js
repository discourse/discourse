import Component from "@ember/component";
import { inject as service } from "@ember/service";

export default Component.extend({
  syntaxHighlighter: service(),

  didRender() {
    if (!this.element.querySelector("code").classList.contains("hljs")) {
      this.syntaxHighlighter.highlightElements(this.element);
    }
  }
});
