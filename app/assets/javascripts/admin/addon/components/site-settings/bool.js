import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";

export default Component.extend({
  tagName: "",

  @discourseComputed("value")
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
    },
  },
});
