import Component from "@glimmer/component";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import I18n from "I18n";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { templateFormFields } from "admin/lib/template-form-fields";

export default class FormTemplateForm extends Component {
  @service router;
  @service dialog;
  @tracked formSubmitted = false;
  @tracked templateContents = this.args.model?.template || "";
  isEditing = this.args.model?.id ? true : false;
  templateName = this.args.model?.name || null;

  @action
  onSubmit() {
    if (!this.formSubmitted) {
      this.formSubmitted = true;
    }

    const postData = {
      name: this.templateName,
      template: this.templateContents,
    };

    if (this.isEditing) {
      postData["id"] = this.args.model.id;

      ajax(`/admin/customize/form-templates/${this.args.model.id}.json`, {
        type: "PUT",
        data: postData,
      })
        .then(() => {
          this.formSubmitted = false;
          this.router.transitionTo("adminCustomizeFormTemplates.index");
        })
        .catch((e) => {
          this.#handleErrors(e);
          this.formSubmitted = false;
        });
    } else {
      ajax("/admin/customize/form-templates.json", {
        type: "POST",
        data: postData,
      })
        .then(() => {
          this.formSubmitted = false;
          this.router.transitionTo("adminCustomizeFormTemplates.index");
        })
        .catch((e) => {
          this.#handleErrors(e);
          this.formSubmitted = false;
        });
    }
  }

  @action
  onCancel() {
    this.router.transitionTo("adminCustomizeFormTemplates.index");
  }

  @action
  onDelete() {
    return this.dialog.yesNoConfirm({
      message: I18n.t("admin.form_templates.delete_confirm", {
        template_name: this.args.model.name,
      }),
      didConfirm: () => {
        ajax(`/admin/customize/form-templates/${this.args.model.id}.json`, {
          type: "DELETE",
        })
          .then(() => {
            this.router.transitionTo("adminCustomizeFormTemplates.index");
          })
          .catch(popupAjaxError);
      },
    });
  }

  @action
  onInsertField(type) {
    const structure = templateFormFields.find(
      (field) => field.type === type
    ).structure;

    if (this.templateContents.length === 0) {
      this.templateContents += structure;
    } else {
      this.templateContents += `\n${structure}`;
    }
  }

  #handleErrors(e) {
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
  }
}
