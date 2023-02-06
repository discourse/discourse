import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import I18n from "I18n";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { templateFormFields } from "admin/lib/template-form-fields";
import FormTemplate from "admin/models/form-template";

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

      FormTemplate.updateTemplate(this.args.model.id, postData)
        .then(() => {
          this.formSubmitted = false;
          this.router.transitionTo("adminCustomizeFormTemplates.index");
        })
        .catch((e) => {
          this.#handleErrors(e);
          this.formSubmitted = false;
        });
    } else {
      FormTemplate.createTemplate(postData)
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
        FormTemplate.deleteTemplate(this.args.model.id)
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
  }
}
