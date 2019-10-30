import { reads } from "@ember/object/computed";
import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  editorId: reads("fieldName"),

  @computed("fieldName")
  currentEditorMode(fieldName) {
    return fieldName === "css" ? "scss" : fieldName;
  },

  @computed("fieldName", "styles.html", "styles.css")
  resetDisabled(fieldName) {
    return (
      this.get(`styles.${fieldName}`) ===
      this.get(`styles.default_${fieldName}`)
    );
  },

  @computed("styles", "fieldName")
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
