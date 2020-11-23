import Component from "@ember/component";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  classNames: ["inline-edit"],

  buffer: null,

  didReceiveAttrs() {
    this._super(...arguments);

    this.set("buffer", this.checked);
  },

  @discourseComputed("checked", "buffer")
  changed(checked, buffer) {
    return !!checked !== !!buffer;
  },

  @action
  apply() {
    this.set("checked", this.buffer);
    this.action();
  },

  @action
  cancel() {
    this.set("buffer", this.checked);
  },
});
