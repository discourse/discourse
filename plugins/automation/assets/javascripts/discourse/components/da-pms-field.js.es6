import { action } from "@ember/object";
import Component from "@ember/component";

export default Component.extend({
  tagName: "",

  didReceiveAttrs() {
    this._super(...arguments);

    if (!this.field.metadata.pms) {
      this.set("field.metadata.pms", []);
    }
  },

  @action
  removePM(pm) {
    this.field.metadata.pms.removeObject(pm);
  },

  @action
  insertPM() {
    this.field.metadata.pms.pushObject({
      title: "",
      raw: "",
      delay: 0,
      encrypt: true
    });
  }
});
