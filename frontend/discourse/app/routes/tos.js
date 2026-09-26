import { service } from "discourse/lib/service";
import DiscourseURL from "discourse/lib/url";
import StaticPage from "discourse/models/static-page";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import SiteSettingsService from "discourse/services/site-settings";

export default class TosRoute extends DiscourseRoute {
  @service(() => SiteSettingsService) siteSettings;

  activate() {
    super.activate(...arguments);
    DiscourseURL.jumpToElement(document.location.hash.slice(1));
  }

  beforeModel(transition) {
    if (this.siteSettings.tos_url) {
      transition.abort();
      DiscourseURL.redirectTo(this.siteSettings.tos_url);
    }
  }

  model() {
    return StaticPage.find("tos");
  }

  titleToken() {
    return i18n("tos");
  }
}
