import DiscourseRoute from "discourse/routes/discourse";
import Group from "discourse/models/group";
import I18n from "I18n";
import { inject as service } from "@ember/service";

export default DiscourseRoute.extend({
  router: service(),

  titleToken() {
    return I18n.t("admin.groups.new.title");
  },

  model() {
    return Group.create({
      automatic: false,
      visibility_level: 0,
      can_admin_group: true,
    });
  },

  setupController(controller, model) {
    controller.set("model", model);
  },

  afterModel() {
    if (!this.get("currentUser.can_create_group")) {
      this.router.transitionTo("groups");
    }
  },
});
