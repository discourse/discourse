import Component from "@ember/component";
import { on } from "@ember-decorators/object";
import highlightSearch from "discourse/lib/highlight-search";
import { observes } from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "span",

  @on("didInsertElement")
  @observes("highlight")
  _highlightOnInsert() {
    const term = this.highlight;
    highlightSearch(this.element, term);
  },
});
