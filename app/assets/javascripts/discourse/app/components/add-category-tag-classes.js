import Component from "@ember/component";
import { scheduleOnce } from "@ember/runloop";

export default Component.extend({
  tagName: "",
  currentClasses: null,

  init() {
    this.currentClasses = new Set();
    this._super();
  },

  didReceiveAttrs() {
    scheduleOnce("afterRender", this, this._updateClasses);
  },

  willDestroyElement() {
    scheduleOnce("afterRender", this, this._removeClasses);
  },

  _updateClasses() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    const desiredClasses = new Set();

    const slug = this.category?.fullSlug;
    if (slug) {
      desiredClasses.add("category");
      desiredClasses.add(`category-${slug}`);
    }
    this.tags?.forEach((t) => desiredClasses.add(`tag-${t}`));

    const addClasses = [...desiredClasses].filter(
      (c) => !this.currentClasses.has(c)
    );
    const removeClasses = [...this.currentClasses].filter(
      (c) => !desiredClasses.has(c)
    );

    document.body.classList.add(...addClasses);
    document.body.classList.remove(...removeClasses);

    this.currentClasses = desiredClasses;
  },

  _removeClasses() {
    document.body.classList.remove(...this.currentClasses);
  },
});
