import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  application: Ember.inject.controller(),

  @computed
  showBadges() {
    return this.currentUser.get("admin") && this.siteSettings.enable_badges;
  },

  @computed("application.currentPath")
  adminContentsClassName(currentPath) {
    return currentPath
      .split(".")
      .filter(segment => {
        return (
          segment !== "index" &&
          segment !== "loading" &&
          segment !== "show" &&
          segment !== "admin"
        );
      })
      .map(Ember.String.dasherize)
      .join(" ");
  }
});
