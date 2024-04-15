import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import StaticPage from "discourse/models/static-page";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class FaqRoute extends DiscourseRoute {
  @service siteSettings;

  pageId = "faq";
  templateName = "faq";

  activate() {
    super.activate(...arguments);
    DiscourseURL.jumpToElement(document.location.hash.slice(1));
  }

  beforeModel(transition) {
    if (this.pageId === "faq" && this.siteSettings.faq_url) {
      transition.abort();
      DiscourseURL.redirectTo(this.siteSettings.faq_url);
    }
  }

  model() {
    return StaticPage.find(this.pageId);
  }

  titleToken() {
    return I18n.t(this.pageId);
  }
}
