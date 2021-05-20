import { observes, on } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import highlightSyntax from "discourse/lib/highlight-syntax";

export default Component.extend({
  @on("didInsertElement")
  @observes("code")
  _refresh() {
    highlightSyntax(this.element, this.siteSettings, this.session);
  },
});
