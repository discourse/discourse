import StaticPage from "discourse/models/static-page";
import { default as DiscourseURL, jumpToElement } from "discourse/lib/url";

const configs = {
  faq: "faq_url",
  tos: "tos_url",
  privacy: "privacy_policy_url"
};

export default function(page) {
  return Discourse.Route.extend({
    renderTemplate() {
      this.render("static");
    },

    beforeModel(transition) {
      const configKey = configs[page];
      if (configKey && Discourse.SiteSettings[configKey].length > 0) {
        transition.abort();
        DiscourseURL.redirectTo(Discourse.SiteSettings[configKey]);
      }
    },

    activate() {
      this._super();
      jumpToElement(document.location.hash.substr(1));
    },

    model() {
      return StaticPage.find(page);
    },

    setupController(controller, model) {
      this.controllerFor("static").set("model", model);
    },

    actions: {
      didTransition() {
        this.controllerFor("application").set("showFooter", true);
        return true;
      }
    }
  });
}
