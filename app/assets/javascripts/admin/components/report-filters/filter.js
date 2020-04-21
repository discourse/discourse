import Component from "@ember/component";
import { action } from "@ember/object";

export default Component.extend({
  @action
  onChange(value) {
    this.applyFilter(this.filter.id, value);
  }
});
