import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export default class AdminCustomizeEmailStyleEditController extends Controller {
  @service dialog;

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
    if (!this.model.saving) {
      this.set("saving", true);
      this.model
        .update(this.model.getProperties("html", "css"))
        .catch((e) => {
          const msg =
            e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors
              ? I18n.t("admin.customize.email_style.save_error_with_reason", {
                  error: e.jqXHR.responseJSON.errors.join(". "),
                })
              : I18n.t("generic_error");
          this.dialog.alert(msg);
        })
        .finally(() => this.set("model.changed", false));
    }
  }
}
