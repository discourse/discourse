import BaseField from "./da-base-field";
import I18n from "I18n";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class PmsField extends BaseField {
  @service dialog;

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    if (!this.field.metadata.value) {
      this.set("field.metadata.value", []);
    }
  }

  @action
  removePM(pm) {
    this.dialog.yesNoConfirm({
      message: I18n.t("discourse_automation.fields.pms.confirm_remove_pm"),
      didConfirm: () => {
        return this.field.metadata.value.removeObject(pm);
      },
    });
  }

  @action
  insertPM() {
    this.field.metadata.value.pushObject({
      title: "",
      raw: "",
      delay: 0,
      prefers_encrypt: true,
    });
  }
}
