import { action } from "@ember/object";
import Controller from "@ember/controller";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { url } from "discourse/lib/computed";
import { inject as service } from "@ember/service";

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
    return isSaving ? I18n.t("saving") : I18n.t("admin.customize.save");
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
    this.router.replaceRoute(
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

        this.router.replaceRoute(
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
    this.router.replaceRoute(this.showRouteName, this.model.id);
  }
}
