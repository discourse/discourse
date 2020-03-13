import Component from "@ember/component";
import { observes } from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "span",

  @observes("selected")
  selectionChanged: function() {
    const selected = this.selected;
    const list = this.selectedList;
    const id = this.selectedId;

    if (selected) {
      list.addObject(id);
    } else {
      list.removeObject(id);
    }
  }
});
