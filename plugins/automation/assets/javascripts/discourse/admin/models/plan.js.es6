import RestModel from "discourse/models/rest";

export default RestModel.extend({
  options: null,

  init() {
    this._super(...arguments);

    this.__type = "plan";

    if (!this.options) {
      this.set("options", Ember.Object.create());
    }
  }
});
