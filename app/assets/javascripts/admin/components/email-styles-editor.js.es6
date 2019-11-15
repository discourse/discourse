import discourseComputed from "discourse-common/utils/decorators";
import { reads } from "@ember/object/computed";
import Component from "@ember/component";

export default Component.extend({
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
    }
  },

  actions: {
    reset() {
      bootbox.confirm(
        I18n.t("admin.customize.email_style.reset_confirm", {
          fieldName: I18n.t(`admin.customize.email_style.${this.fieldName}`)
        }),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            this.styles.setField(
              this.fieldName,
              this.styles.get(`default_${this.fieldName}`)
            );
            this.notifyPropertyChange("editorContents");
          }
        }
      );
    }
  }
});
