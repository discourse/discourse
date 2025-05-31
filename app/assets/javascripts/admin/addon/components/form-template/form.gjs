import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AceEditor from "discourse/components/ace-editor";
import DButton from "discourse/components/d-button";
import FormTemplateFormPreview from "discourse/components/modal/form-template-form-preview";
import TextField from "discourse/components/text-field";
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
    {
      type: "tagchooser",
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
    return this.dialog.deleteConfirm({
      title: i18n("admin.form_templates.delete_confirm"),
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

  <template>
    <div class="form-templates__form">
      <div class="control-group">
        <label for="template-name">
          {{i18n "admin.form_templates.new_template_form.name.label"}}
        </label>
        <TextField
          @value={{this.templateName}}
          @name="template-name"
          @placeholderKey="admin.form_templates.new_template_form.name.placeholder"
          class="form-templates__form-name-input"
        />
      </div>
      <div class="control-group form-templates__editor">
        <div class="form-templates__quick-insert-field-buttons">
          <span>
            {{i18n "admin.form_templates.quick_insert_fields.add_new_field"}}
          </span>
          {{#each this.quickInsertFields as |field|}}
            <DButton
              @icon={{field.icon}}
              @label="admin.form_templates.quick_insert_fields.{{field.type}}"
              @action={{fn this.onInsertField field.type}}
              class="btn-flat btn-icon-text quick-insert-{{field.type}}"
            />
          {{/each}}
          <DButton
            @label="admin.form_templates.validations_modal.button_title"
            @icon="circle-check"
            @action={{this.showValidationOptionsModal}}
            class="btn-flat btn-icon-text form-templates__validations-modal-button"
          />
        </div>
        <DButton
          @icon="eye"
          @label="admin.form_templates.new_template_form.preview"
          @action={{this.showPreview}}
          @disabled={{this.disablePreviewButton}}
          class="form-templates__preview-button"
        />
      </div>

      <div class="control-group">
        <AceEditor
          @content={{this.templateContent}}
          @onChange={{fn (mut this.templateContent)}}
          @mode="yaml"
        />
      </div>

      <div class="footer-buttons">
        <DButton
          @label="admin.form_templates.new_template_form.submit"
          @icon="check"
          @action={{this.onSubmit}}
          @disabled={{this.disableSubmitButton}}
          class="btn-primary"
        />

        <DButton
          @label="admin.form_templates.new_template_form.cancel"
          @icon="xmark"
          @action={{this.onCancel}}
        />

        {{#if this.isEditing}}
          <DButton
            @label="admin.form_templates.view_template.delete"
            @icon="trash-can"
            @action={{this.onDelete}}
            class="btn-danger"
          />
        {{/if}}
      </div>
    </div>

    {{#if this.showFormTemplateFormPreview}}
      <FormTemplateFormPreview
        @closeModal={{fn (mut this.showFormTemplateFormPreview) false}}
        @content={{this.templateContent}}
      />
    {{/if}}
  </template>
}
