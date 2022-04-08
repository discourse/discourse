import Component from "@ember/component";
import { action } from "@ember/object";
import { getOwner } from "discourse-common/lib/get-owner";

export default Component.extend({
  parentController: null,

  @action
  toggleBulkSelect() {
    const controller = getOwner(this).lookup(
      `controller:${this.parentController}`
    );
    const selection = controller.selected;
    controller.toggleProperty("bulkSelectEnabled");
    selection.clear();
  },
});
