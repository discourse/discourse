import Controller from "@ember/controller";
import { url } from "discourse/lib/computed";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend({
  section: null,
  currentTarget: 0,
  maximized: false,
  previewUrl: url("model.id", "/admin/themes/%@/preview"),
  showAdvanced: false,
  editRouteName: "adminCustomizeThemes.edit",
  showRouteName: "adminCustomizeThemes.show",

  setTargetName: function(name) {
    const target = this.get("model.targets").find(t => t.name === name);
    this.set("currentTarget", target && target.id);
  },

  @discourseComputed("currentTarget")
  currentTargetName(id) {
    const target = this.get("model.targets").find(
      t => t.id === parseInt(id, 10)
    );
    return target && target.name;
  },

  @discourseComputed("model.isSaving")
  saveButtonText(isSaving) {
    return isSaving ? I18n.t("saving") : I18n.t("admin.customize.save");
  },

  @discourseComputed("model.changed", "model.isSaving")
  saveDisabled(changed, isSaving) {
    return !changed || isSaving;
  },

  actions: {
    save() {
      this.set("saving", true);
      this.model.saveChanges("theme_fields").finally(() => {
        this.set("saving", false);
      });
    },

    fieldAdded(target, name) {
      this.replaceRoute(this.editRouteName, this.get("model.id"), target, name);
    },

    onlyOverriddenChanged(onlyShowOverridden) {
      if (onlyShowOverridden) {
        if (!this.model.hasEdited(this.currentTargetName, this.fieldName)) {
          let firstTarget = this.get("model.targets").find(t => t.edited);
          let firstField = this.get(`model.fields.${firstTarget.name}`).find(
            f => f.edited
          );

          this.replaceRoute(
            this.editRouteName,
            this.get("model.id"),
            firstTarget.name,
            firstField.name
          );
        }
      }
    }
  }
});
