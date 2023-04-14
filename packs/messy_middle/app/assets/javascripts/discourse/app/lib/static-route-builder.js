import DiscourseURL from "discourse/lib/url";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import StaticPage from "discourse/models/static-page";

const configs = {
  faq: "faq_url",
  tos: "tos_url",
  privacy: "privacy_policy_url",
};

export default function (page) {
  return DiscourseRoute.extend({
    renderTemplate() {
      this.render("static");
    },

    beforeModel(transition) {
      const configKey = configs[page];
      if (configKey && this.siteSettings[configKey].length > 0) {
        transition.abort();
        DiscourseURL.redirectTo(this.siteSettings[configKey]);
      }
    },

    activate() {
      this._super(...arguments);
      DiscourseURL.jumpToElement(document.location.hash.slice(1));
    },

    model() {
      return StaticPage.find(page);
    },

    setupController(controller, model) {
      this.controllerFor("static").set("model", model);
    },

    titleToken() {
      return I18n.t(page);
    },

    actions: {
      didTransition() {
        this.controllerFor("application").set("showFooter", true);
        return true;
      },
    },
  });
}
