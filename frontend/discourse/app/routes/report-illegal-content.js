import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class ReportIllegalContentRoute extends DiscourseRoute {
  model() {
    return ajax("/dsa/illegal-content.json");
  }

  titleToken() {
    return i18n("dsa_notice.title", { site: this.siteSettings.title });
  }
}
