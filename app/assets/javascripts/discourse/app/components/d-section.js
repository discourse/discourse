import Component from "@ember/component";
import { scheduleOnce } from "@ember/runloop";

// Can add a body class from within a component
export default class extends Component {
  tagName = null;
  pageClass = null;
  bodyClass = null;
  currentClasses = new Set();

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
