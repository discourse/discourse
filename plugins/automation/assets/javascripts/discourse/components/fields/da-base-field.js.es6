import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { isPresent } from "@ember/utils";
import { set } from "@ember/object";

export default Component.extend({
  tagName: "",

  forcedValue: null,

  didReceiveAttrs() {
    this._super(...arguments);

    if (this.forcedValue) {
      set(this, "field.metadata.value", this.forcedValue);
    }
  },

  @discourseComputed("forcedValue")
  isDisabled(forcedValue) {
    return isPresent(forcedValue);
  }
});
