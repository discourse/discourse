import DiscourseRoute from "discourse/routes/discourse";
import { action } from "@ember/object";

export default DiscourseRoute.extend({
  serialize() {
    return "";
  },

  @action
  didTransition() {
    this.controllerFor("application").set("showFooter", true);
    return true;
  },
});
