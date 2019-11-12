import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import Component from "@ember/component";

export default Component.extend({
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
    }
  }
});
