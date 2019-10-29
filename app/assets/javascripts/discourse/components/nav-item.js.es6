import { inject as service } from "@ember/service";
import Component from "@ember/component";
/* You might be looking for navigation-item. */
import { iconHTML } from "discourse-common/lib/icon-library";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  tagName: "li",
  classNameBindings: ["active"],
  router: service(),

  @computed("label", "i18nLabel", "icon")
  contents(label, i18nLabel, icon) {
    let text = i18nLabel || I18n.t(label);
    if (icon) {
      return `${iconHTML(icon)} ${text}`.htmlSafe();
    }
    return text;
  },

  @computed("route", "router.currentRoute")
  active(route, currentRoute) {
    if (!route) {
      return;
    }

    const routeParam = this.routeParam;
    if (routeParam && currentRoute) {
      return currentRoute.params["filter"] === routeParam;
    }

    return this.router.isActive(route);
  }
});
