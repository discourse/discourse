import { observes } from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
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
    if (slug) {
      $("body").addClass(`category-${slug}`);
    }
  },

  @observes("category.fullSlug")
  refreshClass() {
    Ember.run.scheduleOnce("afterRender", this, this._updateClass);
  },

  _removeClass() {
    $("body").removeClass((_, css) =>
      (css.match(/\bcategory-\S+/g) || []).join(" ")
    );
  },

  willDestroyElement() {
    this._super(...arguments);
    this._removeClass();
  }
});
