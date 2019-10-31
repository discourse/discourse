import { isEmpty } from "@ember/utils";
import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  @computed("value")
  enabled: {
    get(value) {
      if (isEmpty(value)) {
        return false;
      }
      return value.toString() === "true";
    },
    set(value) {
      this.set("value", value ? "true" : "false");
      return value;
    }
  }
});
