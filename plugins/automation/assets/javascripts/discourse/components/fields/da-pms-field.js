import BaseField from "./da-base-field";
import I18n from "I18n";
import { action } from "@ember/object";
import bootbox from "bootbox";

export default BaseField.extend({
  didReceiveAttrs() {
    this._super(...arguments);

    if (!this.field.metadata.value) {
      this.set("field.metadata.value", []);
    }
  },

  @action
  removePM(pm) {
    bootbox.confirm(
      I18n.t("discourse_automation.fields.pms.confirm_remove_pm"),
      I18n.t("no_value"),
      I18n.t("yes_value"),
      (result) => {
        if (result) {
          this.field.metadata.value.removeObject(pm);
        }
      }
    );
  },

  @action
  insertPM() {
    this.field.metadata.value.pushObject({
      title: "",
      raw: "",
      delay: 0,
      encrypt: true,
    });
  },
});
