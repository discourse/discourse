import { default as computed } from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  application: Ember.inject.controller(),

  @computed("model.automatic", "siteSettings.email_in")
  tabs(automatic, emailIn) {
    const defaultTabs = [
      { route: "group.manage.profile", title: "groups.manage.profile.title" },
      {
        route: "group.manage.interaction",
        title: "groups.manage.interaction.title"
      },
      { route: "group.manage.logs", title: "groups.manage.logs.title" }
    ];

    if (!automatic && emailIn) {
      defaultTabs.splice(2, 0, {
        route: "group.manage.email",
        title: "groups.manage.email.title"
      });
    }

    if (!automatic) {
      defaultTabs.splice(1, 0, {
        route: "group.manage.membership",
        title: "groups.manage.membership.title"
      });
    }

    return defaultTabs;
  }
});
