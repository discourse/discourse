import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default DiscourseRoute.extend({
  router: service(),

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
      this.router.transitionTo("group.members", group);
    }
  },

  @action
  triggerRefresh() {
    this.refresh();
  },
});
