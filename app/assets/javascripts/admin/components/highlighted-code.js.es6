import Component from "@ember/component";
import { on, observes } from "discourse-common/utils/decorators";
import highlightSyntax from "discourse/lib/highlight-syntax";

export default Component.extend({
  @on("didInsertElement")
  @observes("code")
  _refresh: function() {
    highlightSyntax($(this.element));
  }
});
