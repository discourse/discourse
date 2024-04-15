import Controller from "@ember/controller";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import discourseComputed from "discourse-common/utils/decorators";

export default class AdminRevampController extends Controller {
  @service router;

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
