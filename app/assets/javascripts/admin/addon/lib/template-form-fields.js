import { i18n } from "discourse-i18n";

export const templateFormFields = [
  {
    type: "checkbox",
    structure: `- type: checkbox
  id: ${i18n("admin.form_templates.field_placeholders.id")}
  attributes:
    label: "${i18n("admin.form_templates.field_placeholders.label")}"
  validations:
    # ${i18n("admin.form_templates.field_placeholders.validations")}`,
  },
  {
    type: "input",
    structure: `- type: input
  id: ${i18n("admin.form_templates.field_placeholders.id")}
  attributes:
    label: "${i18n("admin.form_templates.field_placeholders.label")}"
    placeholder: "${i18n(
      "admin.form_templates.field_placeholders.placeholder"
    )}"
  validations:
    # ${i18n("admin.form_templates.field_placeholders.validations")}`,
  },
  {
    type: "textarea",
    structure: `- type: textarea
  id: ${i18n("admin.form_templates.field_placeholders.id")}
  attributes:
    label: "${i18n("admin.form_templates.field_placeholders.label")}"
    placeholder: "${i18n(
      "admin.form_templates.field_placeholders.placeholder"
    )}"
  validations:
    # ${i18n("admin.form_templates.field_placeholders.validations")}`,
  },
  {
    type: "dropdown",
    structure: `- type: dropdown
  id: ${i18n("admin.form_templates.field_placeholders.id")}
  choices:
    - "${i18n("admin.form_templates.field_placeholders.choices.first")}"
    - "${i18n("admin.form_templates.field_placeholders.choices.second")}"
    - "${i18n("admin.form_templates.field_placeholders.choices.third")}"
  attributes:
    none_label: "${i18n("admin.form_templates.field_placeholders.none_label")}"
    label: "${i18n("admin.form_templates.field_placeholders.label")}"
  validations:
    # ${i18n("admin.form_templates.field_placeholders.validations")}`,
  },
  {
    type: "upload",
    structure: `- type: upload
  id: ${i18n("admin.form_templates.field_placeholders.id")}
  attributes:
    file_types: ".jpg, .png, .gif"
    allow_multiple: false
    label: "${i18n("admin.form_templates.field_placeholders.label")}"
  validations:
    # ${i18n("admin.form_templates.field_placeholders.validations")}`,
  },
  {
    type: "multiselect",
    structure: `- type: multi-select
  id: ${i18n("admin.form_templates.field_placeholders.id")}
  choices:
    - "${i18n("admin.form_templates.field_placeholders.choices.first")}"
    - "${i18n("admin.form_templates.field_placeholders.choices.second")}"
    - "${i18n("admin.form_templates.field_placeholders.choices.third")}"
  attributes:
    none_label: "${i18n("admin.form_templates.field_placeholders.none_label")}"
    label: "${i18n("admin.form_templates.field_placeholders.label")}"
  validations:
    # ${i18n("admin.form_templates.field_placeholders.validations")}`,
  },
];
