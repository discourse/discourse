import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class CakedayAnniversaries extends DiscourseRoute {
  @service router;

  beforeModel() {
    if (!this.siteSettings.cakeday_enabled) {
      this.router.transitionTo(
        "unknown",
        window.location.pathname.replace(/^\//, "")
      );
    }
  }

  titleToken() {
    return i18n("anniversaries.title");
  }
}
