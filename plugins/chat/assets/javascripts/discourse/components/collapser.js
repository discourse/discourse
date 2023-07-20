import Component from "@ember/component";
import { action } from "@ember/object";

export default Component.extend({
  tagName: "",

  collapsed: false,
  header: null,
  onToggle: null,

  @action
  open() {
    this.set("collapsed", false);
    this.onToggle?.(false);
  },

  @action
  close() {
    this.set("collapsed", true);
    this.onToggle?.(true);
  },
});
