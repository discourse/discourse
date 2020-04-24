import { inject as service } from "@ember/service";
import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend({
  router: service(),

  @discourseComputed("model.automatic")
  tabs(automatic) {
    const defaultTabs = [
      { route: "group.manage.profile", title: "groups.manage.profile.title" },
      {
        route: "group.manage.interaction",
        title: "groups.manage.interaction.title"
      },

      { route: "group.manage.logs", title: "groups.manage.logs.title" }
    ];

    if (!automatic) {
      defaultTabs.splice(1, 0, {
        route: "group.manage.membership",
        title: "groups.manage.membership.title"
      });
    }

    return defaultTabs;
  }
});
