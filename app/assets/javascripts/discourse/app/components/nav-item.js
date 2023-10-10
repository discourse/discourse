import Component from "@ember/component";
/* You might be looking for navigation-item. */
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { iconHTML } from "discourse-common/lib/icon-library";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "I18n";

export default Component.extend({
  tagName: "li",
  classNameBindings: ["active"],
  router: service(),

  @discourseComputed("label", "i18nLabel", "icon")
  contents(label, i18nLabel, icon) {
    let text = i18nLabel || I18n.t(label);
    if (icon) {
      return htmlSafe(`${iconHTML(icon)} ${text}`);
    }
    return text;
  },

  @discourseComputed("route", "router.currentRoute")
  active(route, currentRoute) {
    if (!route) {
      return;
    }

    const routeParam = this.routeParam;
    if (routeParam && currentRoute) {
      return currentRoute.params["filter"] === routeParam;
    }

    return this.router.isActive(route);
  },
});
