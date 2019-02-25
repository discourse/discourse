export default Ember.Component.extend({
  tagName: "",

  buffer: "",
  editing: false,

  init() {
    this._super(...arguments);
    this.set("editing", false);
  },

  actions: {
    edit() {
      this.set("buffer", this.get("value"));
      this.toggleProperty("editing");
    },

    save() {
      // Action has to toggle 'editing' property.
      this.action(this.get("buffer"));
    }
  }
});
