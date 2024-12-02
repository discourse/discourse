import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import FormTemplateValidationOptionsModal from "admin/components/modal/form-template-validation-options";
import { templateFormFields } from "admin/lib/template-form-fields";
import FormTemplate from "admin/models/form-template";

export default class FormTemplateForm extends Component {
  @service router;
  @service dialog;
  @service modal;

  @tracked formSubmitted = false;
  @tracked templateContent = this.args.model?.template || "";
  @tracked templateName = this.args.model?.name || "";
  @tracked showFormTemplateFormPreview;

  isEditing = this.args.model?.id ? true : false;
  quickInsertFields = [
    {
      type: "checkbox",
      icon: "square-check",
    },
    {
      type: "input",
      icon: "grip-lines",
    },
    {
      type: "textarea",
      icon: "align-left",
    },
    {
      type: "dropdown",
      icon: "circle-chevron-down",
    },
    {
      type: "upload",
      icon: "cloud-arrow-up",
    },
    {
      type: "multiselect",
      icon: "bullseye",
    },
  ];

  get disablePreviewButton() {
    return Boolean(!this.templateName.length || !this.templateContent.length);
  }

  get disableSubmitButton() {
    return (
      Boolean(!this.templateName.length || !this.templateContent.length) ||
      this.formSubmitted
    );
  }

  @action
  onSubmit() {
    if (!this.formSubmitted) {
      this.formSubmitted = true;
    }

    const postData = {
      name: this.templateName,
      template: this.templateContent,
    };

    if (this.isEditing) {
      postData["id"] = this.args.model.id;
    }

    FormTemplate.createOrUpdateTemplate(postData)
      .then(() => {
        this.formSubmitted = false;
        this.router.transitionTo("adminCustomizeFormTemplates.index");
      })
      .catch((e) => {
        popupAjaxError(e);
        this.formSubmitted = false;
      });
  }

  @action
  onCancel() {
    this.router.transitionTo("adminCustomizeFormTemplates.index");
  }

  @action
  onDelete() {
    return this.dialog.yesNoConfirm({
      message: i18n("admin.form_templates.delete_confirm"),
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
    const structure = templateFormFields.findBy("type", type).structure;

    if (this.templateContent.length === 0) {
      this.templateContent += structure;
    } else {
      this.templateContent += `\n${structure}`;
    }
  }

  @action
  showValidationOptionsModal() {
    return this.modal.show(FormTemplateValidationOptionsModal);
  }

  @action
  showPreview() {
    const data = {
      name: this.templateName,
      template: this.templateContent,
    };

    if (this.isEditing) {
      data["id"] = this.args.model.id;
    }

    FormTemplate.validateTemplate(data)
      .then(() => {
        this.showFormTemplateFormPreview = true;
      })
      .catch(popupAjaxError);
  }
}
