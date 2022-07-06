import Component from "@ember/component";
import { computed } from "@ember/object";
import { inject as service } from "@ember/service";

export default Component.extend({
  tagName: "",
  route: null,
  router: service(),

  ariaCurrent: computed("router.currentRouteName", "route", function () {
    return this.router.currentRouteName === this.route ? "page" : null;
  }),
});
