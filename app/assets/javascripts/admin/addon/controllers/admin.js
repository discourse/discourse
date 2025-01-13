import Controller from "@ember/controller";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import discourseComputed from "discourse/lib/decorators";

export default class AdminController extends Controller {
  @service router;
  @service currentUser;

  @discourseComputed("currentUser.use_admin_sidebar")
  showAdminSidebar() {
    return this.currentUser.use_admin_sidebar;
  }

  @discourseComputed("siteSettings.enable_group_directory")
  showGroups(enableGroupDirectory) {
    return !enableGroupDirectory;
  }

  @discourseComputed("siteSettings.enable_badges")
  showBadges(enableBadges) {
    return this.currentUser.get("admin") && enableBadges;
  }

  @discourseComputed("router._router.currentPath")
  adminContentsClassName(currentPath) {
    let cssClasses = currentPath
      .split(".")
      .filter((segment) => {
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
}
