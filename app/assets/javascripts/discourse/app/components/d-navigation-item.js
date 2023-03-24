import Component from "@ember/component";
import { computed } from "@ember/object";
import { inject as service } from "@ember/service";

export default Component.extend({
  tagName: "li",

  route: null,

  router: service(),

  attributeBindings: ["ariaCurrent:aria-current", "title"],

  ariaCurrent: computed(
    "router.currentRouteName",
    "router.currentRoute.parent.name",
    "route",
    "ariaCurrentContext",
    function () {
      let ariaCurrentValue = "page";

      // when there are multiple levels of navigation
      // we want the active parent to get `aria-current="page"`
      // and the active child to get `aria-current="location"`
      if (this.ariaCurrentContext === "subNav") {
        ariaCurrentValue = "location";
      } else if (this.ariaCurrentContext === "parentNav") {
        if (
          this.router.currentRouteName !== this.route && // not the current route
          this.router.currentRoute.parent.name.includes(this.route) // but is the current parent route
        ) {
          return "page";
        }
      }

      return this.router.currentRouteName === this.route
        ? ariaCurrentValue
        : null;
    }
  ),
});
