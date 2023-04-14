import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import { action } from "@ember/object";

export default DiscourseRoute.extend({
  titleToken() {
    return I18n.t("groups.messages");
  },

  model() {
    return this.modelFor("group");
  },

  afterModel(group) {
    if (
      !group.get("is_group_user") &&
      !(this.currentUser && this.currentUser.admin)
    ) {
      this.transitionTo("group.members", group);
    }
  },

  @action
  triggerRefresh() {
    this.refresh();
  },
});
