import { inject as service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";

export default class AdminRoute extends DiscourseRoute {
  @service siteSettings;
  @service currentUser;

  titleToken() {
    return I18n.t("admin_title");
  }

  activate() {
    if (
      !this.currentUser.isInAnyGroups(
        this.siteSettings.groupSettingArray(
          "enable_experimental_admin_ui_groups"
        )
      )
    ) {
      return DiscourseURL.redirectTo("/admin");
    }

    this.controllerFor("application").setProperties({
      showTop: false,
    });
  }

  deactivate() {
    this.controllerFor("application").set("showTop", true);
  }
}
