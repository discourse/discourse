import deprecated from "discourse-common/lib/deprecated";
import Component from "@ember/component";
import { scrollTop } from "discourse/mixins/scroll-top";

// Can add a body class from within a component, also will scroll to the top automatically.
export default Component.extend({
  tagName: null,
  pageClass: null,
  bodyClass: null,
  scrollTop: true,

  didInsertElement() {
    this._super(...arguments);

    if (this.pageClass) {
      document.body.classList.add(`${this.pageClass}-page`);
    }

    if (this.bodyClass) {
      document.body.classList.add(...this.bodyClass.split(" "));
    }

    if (this.scrollTop === "false") {
      deprecated("Uses boolean instead of string for scrollTop.", {
        since: "2.8.0.beta9",
        dropFrom: "2.9.0.beta1",
      });

      return;
    }

    if (!this.scrollTop) {
      return;
    }

    scrollTop();
  },

  willDestroyElement() {
    this._super(...arguments);

    if (this.pageClass) {
      document.body.classList.remove(`${this.pageClass}-page`);
    }

    if (this.bodyClass) {
      document.body.classList.remove(...this.bodyClass.split(" "));
    }
  },
});
