import Component from "@ember/component";
import { action } from "@ember/object";

export default Component.extend({
  @action
  changed(value) {
    this.set("field.value", value);
  },
});
