import RestModel from "discourse/models/rest";

export default RestModel.extend({
  options: null,

  init() {
    this._super(...arguments);

    this.__type = "trigger";

    if (!this.options) {
      this.set("options", Ember.Object.create());
    }
  },

  availablePlaceholders: Ember.computed(
    "specification.placeholders",
    function() {
      return Object.keys(this.specification.placeholders);
    }
  )
});
