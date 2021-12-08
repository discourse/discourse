import Component from "@ember/component";
import { observes } from "discourse-common/utils/decorators";
import { scheduleOnce } from "@ember/runloop";

export default Component.extend({
  _slug: null,

  didInsertElement() {
    this._super(...arguments);
    this.refreshClass();
  },

  _updateClass() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }
    const slug = this.get("category.fullSlug");

    this._removeClass();

    let classes = [];

    if (slug) {
      classes.push("category");
      classes.push(`category-${slug}`);
    }

    this.tags?.forEach((t) => classes.push(`tag-${t}`));

    document.documentElement.classList.add(...classes);
  },

  @observes("category.fullSlug", "tags")
  refreshClass() {
    scheduleOnce("afterRender", this, this._updateClass);
  },

  willDestroyElement() {
    this._super(...arguments);
    this._removeClass();
  },

  _removeClass() {
    const invalidClasses = [];
    const regex = /\b(?:category|tag)-\S+|( category )/g;

    document.documentElement.classList.forEach((name) => {
      if (name.match(regex)) {
        invalidClasses.push(name);
      }
    });

    if (invalidClasses.length) {
      document.documentElement.classList.remove(...[invalidClasses]);
    }
  },
});
