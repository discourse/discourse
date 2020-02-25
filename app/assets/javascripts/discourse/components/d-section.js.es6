import Component from "@ember/component";
import { scrollTop } from "discourse/mixins/scroll-top";

// Can add a body class from within a component, also will scroll to the top automatically.
export default Component.extend({
  tagName: "section",

  didInsertElement() {
    this._super(...arguments);

    const pageClass = this.pageClass;
    if (pageClass) {
      $("body").addClass(`${pageClass}-page`);
    }

    const bodyClass = this.bodyClass;
    if (bodyClass) {
      $("body").addClass(bodyClass);
    }

    if (this.scrollTop === "false") {
      return;
    }

    scrollTop();
  },

  willDestroyElement() {
    this._super(...arguments);
    const pageClass = this.pageClass;
    if (pageClass) {
      $("body").removeClass(`${pageClass}-page`);
    }

    const bodyClass = this.bodyClass;
    if (bodyClass) {
      $("body").removeClass(bodyClass);
    }
  }
});
