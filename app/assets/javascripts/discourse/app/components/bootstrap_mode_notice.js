import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import I18n from "I18n";
import { alias } from "@ember/object/computed";
import { htmlSafe } from "@ember/template";
import { inject as service } from "@ember/service";

export default Component.extend({
  router: service(),
  classNameBindings: ["hidden:hidden", ":bootstrap-notice"],

  wizardRequired: alias("site.wizard_required"),
  bootstrapModeEnabled: alias("siteSettings.bootstrap_mode_enabled"),
  bootstrapModeMinUsers: alias("siteSettings.bootstrap_mode_min_users"),

  @discourseComputed("bootstrapModeEnabled", "router.currentRouteName")
  hidden(bootstrapModeEnabled, currentRouteName) {
    const user = this.currentUser;
    return !(
      user &&
      user.get("staff") &&
      bootstrapModeEnabled &&
      !currentRouteName.startsWith("wizard")
    );
  },

  @discourseComputed("bootstrapModeMinUsers")
  message(bootstrapModeMinUsers) {
    let msg = null;

    if (bootstrapModeMinUsers > 0) {
      msg = "bootstrap_mode_banner.enabled";
    } else {
      msg = "bootstrap_mode_banner.disabled";
    }

    return htmlSafe(I18n.t(msg, { count: bootstrapModeMinUsers }));
  },
});
