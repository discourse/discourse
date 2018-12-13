export default Ember.Component.extend({
  tagName: "",

  buffer: "",
  editing: false,

  init() {
    this._super();
    this.set("editing", false);
  },

  actions: {
    edit() {
      this.set("buffer", this.get("value"));
      this.toggleProperty("editing");
    },

    save() {
      // Action has to toggle 'editing' property.
      this.sendAction("action", this.get("buffer"));
    }
  }
});
