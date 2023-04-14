import Controller, { inject as controller } from "@ember/controller";
import { observes } from "discourse-common/utils/decorators";

export default Controller.extend({
  application: controller(),

  @observes("model.canLoadMore")
  _showFooter() {
    this.set("application.showFooter", !this.get("model.canLoadMore"));
  },
});
