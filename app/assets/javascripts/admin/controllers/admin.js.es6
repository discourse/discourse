import discourseComputed from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";
import Controller from "@ember/controller";
import { dasherize } from "@ember/string";

export default Controller.extend({
  router: service(),

  @discourseComputed("siteSettings.enable_group_directory")
  showGroups(enableGroupDirectory) {
    return !enableGroupDirectory;
  },

  @discourseComputed("siteSettings.enable_badges")
  showBadges(enableBadges) {
    return this.currentUser.get("admin") && enableBadges;
  },

  @discourseComputed("router._router.currentPath")
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
      .map(dasherize)
      .join(" ");

    // this is done to avoid breaking css customizations
    if (cssClasses.includes("dashboard")) {
      cssClasses = `${cssClasses} dashboard-next`;
    }

    return cssClasses;
  }
});
