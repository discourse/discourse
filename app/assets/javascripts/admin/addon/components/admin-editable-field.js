import Component from "@ember/component";
import { action } from "@ember/object";

export default Component.extend({
  tagName: "",

  buffer: "",
  editing: false,

  init() {
    this._super(...arguments);
    this.set("editing", false);
  },

  @action
  edit(event) {
    event?.preventDefault();
    this.set("buffer", this.value);
    this.toggleProperty("editing");
  },

  actions: {
    save() {
      // Action has to toggle 'editing' property.
      this.action(this.buffer);
    },
  },
});
