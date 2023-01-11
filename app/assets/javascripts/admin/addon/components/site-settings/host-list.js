import Component from "@ember/component";
import { action, computed } from "@ember/object";

export default Component.extend({
  tokenSeparator: "|",
  choices: null,

  @computed("value")
  get settingValue() {
    return this.value.toString().split(this.tokenSeparator).filter(Boolean);
  },

  @action
  onChange(value) {
    if (value.some((v) => v.includes("?") || v.includes("*"))) {
      return;
    }

    this.set("value", value.join(this.tokenSeparator));
  },
});
