import Component from "@glimmer/component";
import I18n from "I18n";

const TABLE_HEADER_KEYS = ["key", "type", "description"];
const VALIDATION_KEYS = ["required", "minimum", "maximum", "pattern", "type"];

export default class FormTemplateValidationOptions extends Component {
  get tableHeaders() {
    const translatedHeaders = [];
    TABLE_HEADER_KEYS.forEach((header) => {
      translatedHeaders.push(
        I18n.t(`admin.form_templates.validations_modal.table_headers.${header}`)
      );
    });

    return translatedHeaders;
  }

  get validations() {
    const translatedValidations = [];
    const prefix = "admin.form_templates.validations_modal.validations";
    VALIDATION_KEYS.forEach((validation) => {
      translatedValidations.push({
        key: I18n.t(`${prefix}.${validation}.key`),
        type: I18n.t(`${prefix}.${validation}.type`),
        description: I18n.t(`${prefix}.${validation}.description`),
      });
    });

    return translatedValidations;
  }
}
