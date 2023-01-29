import deprecated from "discourse-common/lib/deprecated";
import Component from "@ember/component";
import { scrollTop } from "discourse/mixins/scroll-top";
import { scheduleOnce } from "@ember/runloop";

// Can add a body class from within a component, also will scroll to the top automatically.
export default class extends Component {
  tagName = null;
  pageClass = null;
  bodyClass = null;
  scrollTop = true;
  currentClasses = new Set();

  didInsertElement() {
    this._super(...arguments);

    if (this.scrollTop === "false") {
      deprecated("Uses boolean instead of string for scrollTop.", {
        since: "2.8.0.beta9",
        dropFrom: "2.9.0.beta1",
        id: "discourse.d-section.scroll-top-boolean",
      });

      return;
    }

    if (!this.scrollTop) {
      return;
    }

    scrollTop();
  }

  didReceiveAttrs() {
    this._super(...arguments);
    scheduleOnce("afterRender", this, this._updateClasses);
  }

  willDestroyElement() {
    this._super(...arguments);
    scheduleOnce("afterRender", this, this._removeClasses);
  }

  _updateClasses() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    const desiredClasses = new Set();
    if (this.pageClass) {
      desiredClasses.add(`${this.pageClass}-page`);
    }
    if (this.bodyClass) {
      for (const bodyClass of this.bodyClass.split(" ")) {
        desiredClasses.add(bodyClass);
      }
    }

    document.body.classList.add(...desiredClasses);
    const removeClasses = [...this.currentClasses].filter(
      (c) => !desiredClasses.has(c)
    );
    document.body.classList.remove(...removeClasses);
    this.currentClasses = desiredClasses;
  }

  _removeClasses() {
    document.body.classList.remove(...this.currentClasses);
  }
}
