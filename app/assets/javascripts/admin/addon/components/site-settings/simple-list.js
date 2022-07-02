import Component from "@ember/component";
import { action } from "@ember/object";

export default Component.extend({
  tagName: "",
  inputDelimiter: "|",

  @action
  onChange(value) {
    this.set("value", value.join(this.inputDelimiter || "\n"));
  }
});
