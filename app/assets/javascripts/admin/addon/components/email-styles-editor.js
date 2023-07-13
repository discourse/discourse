import { action, computed } from "@ember/object";
import { inject as service } from "@ember/service";
import { reads } from "@ember/object/computed";
import Component from "@ember/component";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";

export default class EmailStylesEditor extends Component {
  @service dialog;

  @reads("fieldName") editorId;

  @discourseComputed("fieldName")
  currentEditorMode(fieldName) {
    return fieldName === "css" ? "scss" : fieldName;
  }

  @discourseComputed("fieldName", "styles.html", "styles.css")
  resetDisabled(fieldName) {
    return (
      this.get(`styles.${fieldName}`) ===
      this.get(`styles.default_${fieldName}`)
    );
  }

  @computed("styles", "fieldName")
  get editorContents() {
    return this.styles[this.fieldName];
  }

  set editorContents(value) {
    this.styles.setField(this.fieldName, value);
    return value;
  }

  @action
  reset() {
    this.dialog.yesNoConfirm({
      message: I18n.t("admin.customize.email_style.reset_confirm", {
        fieldName: I18n.t(`admin.customize.email_style.${this.fieldName}`),
      }),
      didConfirm: () => {
        this.styles.setField(
          this.fieldName,
          this.styles.get(`default_${this.fieldName}`)
        );
        this.notifyPropertyChange("editorContents");
      },
    });
  }
}
