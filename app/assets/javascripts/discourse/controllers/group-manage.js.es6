import { default as computed } from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  application: Ember.inject.controller(),

  @computed("model.automatic")
  tabs(automatic) {
    const defaultTabs = [
      {
        route: "group.manage.interaction",
        title: "groups.manage.interaction.title"
      },
      { route: "group.manage.logs", title: "groups.manage.logs.title" }
    ];

    if (!automatic) {
      defaultTabs.splice(0, 0, {
        route: "group.manage.profile",
        title: "groups.manage.profile.title"
      });

      defaultTabs.splice(1, 0, {
        route: "group.manage.membership",
        title: "groups.manage.membership.title"
      });
    }

    return defaultTabs;
  }
});
