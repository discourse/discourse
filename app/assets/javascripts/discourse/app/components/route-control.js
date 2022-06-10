import Component from "@ember/component";
import { inject as service } from "@ember/service";
import discourseComputed from "discourse-common/utils/decorators";
import { defaultHomepage } from "discourse/lib/utilities";

export default Component.extend({
  tagName: "div",
  router: service(),

  @discourseComputed("router.currentRouteName", "showOn")
  canDisplay(currentRouteName, showOn) {
    if (showOn === "homepage") {
      return this.handleHomepageRoute(currentRouteName);
    } else if (showOn === currentRouteName) {
      return true;
    } else {
      return false;
    }
  },

  handleHomepageRoute(currentRouteName) {
    const topMenu = this.siteSettings.top_menu;

    if (currentRouteName === `discovery.${defaultHomepage()}`) {
      return true;
    } else if (
      topMenu.split("|").any((m) => `discovery.${m}` === currentRouteName)
    ) {
      return true;
    } else {
      return false;
    }
  },
});
