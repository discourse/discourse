import I18n from "I18n";
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
    bootbox.confirm(
      I18n.t("discourse_automation.fields.pms.confirm_remove_pm"),
      I18n.t("no_value"),
      I18n.t("yes_value"),
      result => {
        if (result) {
          this.field.metadata.pms.removeObject(pm);
        }
      }
    );
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
