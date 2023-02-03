import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { inject as service } from "@ember/service";
import I18n from "I18n";

export default class AdminCustomizeForTemplatesNew extends Controller {
  @service router;
  @service dialog;
  templateName = null;
  templateContents = null;
  formSubmitted = false;

  @action
  onSubmit() {
    if (!this.formSubmitted) {
      this.formSubmitted = true;
    }

    ajax("/admin/customize/form_templates.json", {
      type: "POST",
      data: {
        name: this.templateName,
        template: this.templateContents,
      },
    })
      .then(() => {
        this.formSubmitted = false;
        this.router.transitionTo("adminCustomizeFormTemplates.index");
      })
      .catch((e) => {
        this.formSubmitted = false;
        let error;

        if (e?.jqXHR?.responseJSON?.errors) {
          error = I18n.t("generic_error_with_reason", {
            error: e.jqXHR.responseJSON.errors.join(". "),
          });
        } else {
          error = I18n.t("generic_error");
        }

        this.dialog.alert({
          message: error,
        });

        // todo remove later only for testing:
        // console.error("error: ", e);
      });
  }
}
