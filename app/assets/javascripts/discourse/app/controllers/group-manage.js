import Controller from "@ember/controller";
import discourseComputed from "discourse/lib/decorators";

export default class GroupManageController extends Controller {
  @discourseComputed("model.automatic")
  tabs(automatic) {
    const defaultTabs = [
      { route: "group.manage.profile", title: "groups.manage.profile.title" },
      {
        route: "group.manage.interaction",
        title: "groups.manage.interaction.title",
      },
      {
        route: "group.manage.categories",
        title: "groups.manage.categories.title",
      },
    ];

    if (this.siteSettings.tagging_enabled) {
      defaultTabs.push({
        route: "group.manage.tags",
        title: "groups.manage.tags.title",
      });
    }

    defaultTabs.push({
      route: "group.manage.logs",
      title: "groups.manage.logs.title",
    });

    if (!automatic) {
      if (this.siteSettings.enable_smtp) {
        defaultTabs.splice(2, 0, {
          route: "group.manage.email",
          title: "groups.manage.email.title",
        });
      }

      defaultTabs.splice(1, 0, {
        route: "group.manage.membership",
        title: "groups.manage.membership.title",
      });
    }

    return defaultTabs;
  }
}
