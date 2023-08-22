import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import StaticPage from "discourse/models/static-page";
import I18n from "I18n";

export default class PrivacyRoute extends DiscourseRoute {
  @service siteSettings;

  activate() {
    super.activate(...arguments);
    DiscourseURL.jumpToElement(document.location.hash.slice(1));
  }

  beforeModel(transition) {
    if (this.siteSettings.privacy_policy_url) {
      transition.abort();
      DiscourseURL.redirectTo(this.siteSettings.privacy_policy_url);
    }
  }

  model() {
    return StaticPage.find("privacy");
  }

  titleToken() {
    return I18n.t("privacy");
  }
}
