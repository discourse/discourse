import I18n from "I18n";

export const templateFormFields = [
  {
    type: "checkbox",
    structure: `- type: checkbox
  attributes:
    label: "${I18n.t("admin.form_templates.field_placeholders.label")}"
  validations:
    # ${I18n.t("admin.form_templates.field_placeholders.validations")}`,
  },
  {
    type: "input",
    structure: `- type: input
  attributes:
    label: "${I18n.t("admin.form_templates.field_placeholders.label")}"
    placeholder: "${I18n.t(
      "admin.form_templates.field_placeholders.placeholder"
    )}"
  validations:
    # ${I18n.t("admin.form_templates.field_placeholders.validations")}`,
  },
  {
    type: "textarea",
    structure: `- type: textarea
  attributes:
    label: "${I18n.t("admin.form_templates.field_placeholders.label")}"
    placeholder: "${I18n.t(
      "admin.form_templates.field_placeholders.placeholder"
    )}"
  validations:
    # ${I18n.t("admin.form_templates.field_placeholders.validations")}`,
  },
  {
    type: "dropdown",
    structure: `- type: dropdown
  choices:
    - "${I18n.t("admin.form_templates.field_placeholders.choices.first")}"
    - "${I18n.t("admin.form_templates.field_placeholders.choices.second")}"
    - "${I18n.t("admin.form_templates.field_placeholders.choices.third")}"
  attributes:
    none_label: "${I18n.t(
      "admin.form_templates.field_placeholders.none_label"
    )}"
    label: "${I18n.t("admin.form_templates.field_placeholders.label")}"
    filterable: false
  validations:
    # ${I18n.t("admin.form_templates.field_placeholders.validations")}`,
  },
  {
    type: "upload",
    structure: `- type: upload
  attributes:
    file_types: "jpg, png, gif"
    allow_multiple: false
    label: "${I18n.t("admin.form_templates.field_placeholders.label")}"
  validations:
    # ${I18n.t("admin.form_templates.field_placeholders.validations")}`,
  },
  {
    type: "multiselect",
    structure: `- type: multi-select
  choices:
    - "${I18n.t("admin.form_templates.field_placeholders.choices.first")}"
    - "${I18n.t("admin.form_templates.field_placeholders.choices.second")}"
    - "${I18n.t("admin.form_templates.field_placeholders.choices.third")}"
  attributes:
    none_label: "${I18n.t(
      "admin.form_templates.field_placeholders.none_label"
    )}"
    label: "${I18n.t("admin.form_templates.field_placeholders.label")}"
  validations:
    # ${I18n.t("admin.form_templates.field_placeholders.validations")}`,
  },
];
