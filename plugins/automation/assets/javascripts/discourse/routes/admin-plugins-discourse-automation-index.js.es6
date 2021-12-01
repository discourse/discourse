import { action } from "@ember/object";
import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  controllerName: "admin-plugins-discourse-automation-index",

  model() {
    return this.store.findAll("discourse-automation-automation");
  },

  @action
  triggerRefresh() {
    this.refresh();
  },
});
