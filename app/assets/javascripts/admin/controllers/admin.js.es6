import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  router: Ember.inject.service(),

  @computed("siteSettings.enable_group_directory")
  showGroups(enableGroupDirectory) {
    return !enableGroupDirectory;
  },

  @computed("siteSettings.enable_badges")
  showBadges(enableBadges) {
    return this.currentUser.get("admin") && enableBadges;
  },

  @computed("router.currentRouteName")
  adminContentsClassName(currentPath) {
    let cssClasses = currentPath
      .split(".")
      .filter(segment => {
        return (
          segment !== "index" &&
          segment !== "loading" &&
          segment !== "show" &&
          segment !== "admin" &&
          segment !== "dashboard"
        );
      })
      .map(Ember.String.dasherize)
      .join(" ");

    // this is done to avoid breaking css customizations
    if (currentPath.indexOf("admin.dashboard") > -1) {
      cssClasses = `${cssClasses} dashboard dashboard-next`;
    }

    return cssClasses;
  }
});
