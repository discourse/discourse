import Controller from "@ember/controller";
import { computed } from "@ember/object";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";

export default class AdminController extends Controller {
  @service router;
  @service currentUser;

  @computed("siteSettings.enable_group_directory")
  get showGroups() {
    return !this.siteSettings?.enable_group_directory;
  }

  @computed("siteSettings.enable_badges")
  get showBadges() {
    return this.currentUser.get("admin") && this.siteSettings?.enable_badges;
  }

  @computed("router._router.currentPath")
  get adminContentsClassName() {
    let cssClasses = this.router?._router?.currentPath
      ?.split(".")
      ?.filter((segment) => {
        return (
          segment !== "index" &&
          segment !== "loading" &&
          segment !== "show" &&
          segment !== "admin"
        );
      })
      ?.map(dasherize)
      ?.join(" ");

    // this is done to avoid breaking css customizations
    if (cssClasses.includes("dashboard")) {
      cssClasses = `${cssClasses} dashboard-next`;
    }

    return cssClasses;
  }
}
