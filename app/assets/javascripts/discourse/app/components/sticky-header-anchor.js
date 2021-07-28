import Component from "@ember/component";
import { isTesting } from "discourse-common/config/environment";

export default Component.extend({
  classNames: "sticky-header-anchor",
  _stickyHeaderObserver: null,
  _container: isTesting()
    ? document.querySelector(".ember-testing")
    : document.body,

  didInsertElement() {
    this._super(...arguments);

    if (this.element) {
      this._stickyHeaderObserver = new IntersectionObserver((entries) => {
        if (!entries[0].isIntersecting) {
          this._container.classList.add("docked");
        } else {
          this._container.classList.remove("docked");
        }
      }).observe(this.element);
    }
  },

  willDestroyElement() {
    this._super(...arguments);
    this._stickyHeaderDockObserver?.unobserve(this.element);
  },
});
