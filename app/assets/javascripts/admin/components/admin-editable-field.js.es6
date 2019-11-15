import Component from "@ember/component";
export default Component.extend({
  tagName: "",

  buffer: "",
  editing: false,

  init() {
    this._super(...arguments);
    this.set("editing", false);
  },

  actions: {
    edit() {
      this.set("buffer", this.value);
      this.toggleProperty("editing");
    },

    save() {
      // Action has to toggle 'editing' property.
      this.action(this.buffer);
    }
  }
});
