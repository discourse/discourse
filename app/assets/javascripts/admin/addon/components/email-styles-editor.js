import Component from "@ember/component";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { reads } from "@ember/object/computed";
import { inject as service } from "@ember/service";

export default Component.extend({
  dialog: service(),
  editorId: reads("fieldName"),

  @discourseComputed("fieldName")
  currentEditorMode(fieldName) {
    return fieldName === "css" ? "scss" : fieldName;
  },

  @discourseComputed("fieldName", "styles.html", "styles.css")
  resetDisabled(fieldName) {
    return (
      this.get(`styles.${fieldName}`) ===
      this.get(`styles.default_${fieldName}`)
    );
  },

  @discourseComputed("styles", "fieldName")
  editorContents: {
    get(styles, fieldName) {
      return styles[fieldName];
    },
    set(value, styles, fieldName) {
      styles.setField(fieldName, value);
      return value;
    },
  },

  actions: {
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
    },
    save() {
      this.attrs.save();
    },
  },
});
