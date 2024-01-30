import Component from "@ember/component";
import { action } from "@ember/object";

export default Component.extend({
  tagName: "",
  expandDetails: false,

  @action
  toggleDetails() {
    this.toggleProperty("expandDetails");
  },

  @action
  filter(params) {
    this.set(`filters.${params.key}`, params.value);
  },
});
