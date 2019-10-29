import { scheduleOnce } from "@ember/runloop";
import Component from "@ember/component";
import { observes } from "ember-addons/ember-computed-decorators";

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
    const tags = this.tags;

    this._removeClass();

    let classes = [];
    if (slug) classes.push(`category-${slug}`);
    if (tags) tags.forEach(t => classes.push(`tag-${t}`));
    if (classes.length > 0) $("body").addClass(classes.join(" "));
  },

  @observes("category.fullSlug", "tags")
  refreshClass() {
    scheduleOnce("afterRender", this, this._updateClass);
  },

  _removeClass() {
    $("body").removeClass((_, css) =>
      (css.match(/\b(?:category|tag)-\S+/g) || []).join(" ")
    );
  },

  willDestroyElement() {
    this._super(...arguments);
    this._removeClass();
  }
});
