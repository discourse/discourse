import Component from "@ember/component";
import { computed } from "@ember/object";
import { inject as service } from "@ember/service";

export default Component.extend({
  tagName: "li",

  route: null,

  router: service(),

  attributeBindings: ["ariaCurrent:aria-current", "title"],

  ariaCurrent: computed("router.currentRouteName", "route", function () {
    return this.router.currentRouteName === this.route ? "page" : null;
  }),
});
