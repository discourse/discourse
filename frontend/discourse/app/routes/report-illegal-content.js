import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class ReportIllegalContentRoute extends DiscourseRoute {
  @service router;

  beforeModel() {
    if (!this.siteSettings.dsa_reporting_enabled) {
      return this.router.replaceWith("exception-unknown");
    }
  }

  titleToken() {
    return i18n("dsa_notice.title", { site: this.siteSettings.title });
  }
}
