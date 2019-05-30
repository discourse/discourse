import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  application: Ember.inject.controller(),

  @computed("siteSettings.enable_group_directory")
  showGroups(enableGroupDirectory) {
    return !enableGroupDirectory;
  },

  @computed("siteSettings.enable_badges")
  showBadges(enableBadges) {
    return this.currentUser.admin && enableBadges;
  },

  @computed("application.currentPath")
  adminContentsClassName(currentPath) {
    let cssClasses = currentPath
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

    // this is done to avoid breaking css customizations
    if (cssClasses.includes("dashboard")) {
      cssClasses = `${cssClasses} dashboard-next`;
    }

    return cssClasses;
  }
});
