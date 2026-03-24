import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class AdminCustomizeEmailStyleEditController extends Controller {
  @service dialog;

  @computed("model.isSaving")
  get saveButtonText() {
    return this.model?.isSaving ? i18n("saving") : i18n("admin.customize.save");
  }

  @computed("model.changed", "model.isSaving")
  get saveDisabled() {
    return !this.model?.changed || this.model?.isSaving;
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
              ? i18n("admin.customize.email_style.save_error_with_reason", {
                  error: e.jqXHR.responseJSON.errors.join(". "),
                })
              : i18n("generic_error");
          this.dialog.alert(msg);
        })
        .finally(() => this.set("model.changed", false));
    }
  }
}
