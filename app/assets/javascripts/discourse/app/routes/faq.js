import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import StaticPage from "discourse/models/static-page";
import I18n from "I18n";
import { action } from "@ember/object";

export default class FaqRoute extends DiscourseRoute {
  @service siteSettings;

  pageId = "faq";
  templateName = "faq";

  activate() {
    super.activate(...arguments);
    DiscourseURL.jumpToElement(document.location.hash.slice(1));
  }

  beforeModel(transition) {
    if (this.pageId === "faq" && this.siteSettings["faq_url"]) {
      transition.abort();
      DiscourseURL.redirectTo(this.siteSettings["faq_url"]);
    }
  }

  model() {
    return StaticPage.find(this.pageId);
  }

  titleToken() {
    return I18n.t(this.pageId);
  }

  @action
  didTransition() {
    this.controllerFor("application").set("showFooter", true);
    return true;
  }
}
