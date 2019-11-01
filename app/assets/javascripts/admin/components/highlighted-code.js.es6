import Component from "@ember/component";
import { on, observes } from "ember-addons/ember-computed-decorators";
import highlightSyntax from "discourse/lib/highlight-syntax";

export default Component.extend({
  @on("didInsertElement")
  @observes("code")
  _refresh: function() {
    highlightSyntax($(this.element));
  }
});
