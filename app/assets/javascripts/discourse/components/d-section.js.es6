import { scrollTop } from "discourse/mixins/scroll-top";

// Can add a body class from within a component, also will scroll to the top automatically.
export default Ember.Component.extend({
  tagName: "section",

  didInsertElement() {
    this._super(...arguments);

    const pageClass = this.get("pageClass");
    if (pageClass) {
      $("body").addClass(`${pageClass}-page`);
    }

    const bodyClass = this.get("bodyClass");
    if (bodyClass) {
      $("body").addClass(bodyClass);
    }

    if (this.get("scrollTop") === "false") {
      return;
    }

    scrollTop();
  },

  willDestroyElement() {
    this._super(...arguments);
    const pageClass = this.get("pageClass");
    if (pageClass) {
      $("body").removeClass(`${pageClass}-page`);
    }

    const bodyClass = this.get("bodyClass");
    if (bodyClass) {
      $("body").removeClass(bodyClass);
    }
  }
});
