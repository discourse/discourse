import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import { observes } from "discourse-common/utils/decorators";

export default Controller.extend({
  application: inject(),

  @observes("model.canLoadMore")
  _showFooter: function() {
    this.set("application.showFooter", !this.get("model.canLoadMore"));
  }
});
