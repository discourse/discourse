import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { url } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class AdminCustomizeThemesEditController extends Controller {
  @service router;

  section = null;
  currentTarget = 0;
  maximized = false;

  @url("model.id", "/admin/themes/%@/preview") previewUrl;

  showAdvanced = false;
  editRouteName = "adminCustomizeThemes.edit";
  showRouteName = "adminCustomizeThemes.show";

  setTargetName(name) {
    const target = this.get("model.targets").find((t) => t.name === name);
    this.set("currentTarget", target && target.id);
  }

  @discourseComputed("currentTarget")
  currentTargetName(id) {
    const target = this.get("model.targets").find(
      (t) => t.id === parseInt(id, 10)
    );
    return target && target.name;
  }

  @discourseComputed("model.isSaving")
  saveButtonText(isSaving) {
    return isSaving ? i18n("saving") : i18n("admin.customize.save");
  }

  @discourseComputed("model.changed", "model.isSaving")
  saveDisabled(changed, isSaving) {
    return !changed || isSaving;
  }

  @action
  save() {
    this.set("saving", true);
    this.model.saveChanges("theme_fields").finally(() => {
      this.set("saving", false);
    });
  }

  @action
  fieldAdded(target, name) {
    this.router.replaceWith(
      this.editRouteName,
      this.get("model.id"),
      target,
      name
    );
  }

  @action
  onlyOverriddenChanged(onlyShowOverridden) {
    if (onlyShowOverridden) {
      if (!this.model.hasEdited(this.currentTargetName, this.fieldName)) {
        let firstTarget = this.get("model.targets").find((t) => t.edited);
        let firstField = this.get(`model.fields.${firstTarget.name}`).find(
          (f) => f.edited
        );

        this.router.replaceWith(
          this.editRouteName,
          this.get("model.id"),
          firstTarget.name,
          firstField.name
        );
      }
    }
  }

  @action
  goBack() {
    this.router.replaceWith(this.showRouteName, this.model.id);
  }
}
