import DiscourseRoute from "discourse/routes/discourse";
import AssociatedGroup from "discourse/models/associated-group";
import I18n from "I18n";

export default DiscourseRoute.extend({
  showFooter: true,

  titleToken() {
    return I18n.t("groups.manage.membership.title");
  },

  afterModel(group) {
    if (group.get("automatic")) {
      this.replaceWith("group.manage.interaction", group);
    }

    if (this.currentUser && this.currentUser.admin) {
      return AssociatedGroup.list().then((associatedGroups) => {
        this.associatedGroups = associatedGroups;
      });
    }
  },

  setupController(controller, model) {
    controller.set("model", model);

    if (this.associatedGroups) {
      controller.set("associatedGroups", this.associatedGroups);
    }
  },
});
