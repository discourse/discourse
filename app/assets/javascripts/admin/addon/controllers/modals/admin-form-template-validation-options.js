import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import I18n from "I18n";

export default class AdminFormTemplateValidationOptions extends Controller.extend(
  ModalFunctionality
) {
  TABLE_HEADER_KEYS = ["key", "type", "description"];
  VALIDATION_KEYS = ["required", "minimum", "maximum", "pattern"];

  get tableHeaders() {
    const translatedHeaders = [];
    this.TABLE_HEADER_KEYS.forEach((header) => {
      translatedHeaders.push(
        I18n.t(`admin.form_templates.validations_modal.table_headers.${header}`)
      );
    });

    return translatedHeaders;
  }

  get validations() {
    const translatedValidations = [];
    const prefix = "admin.form_templates.validations_modal.validations";
    this.VALIDATION_KEYS.forEach((validation) => {
      translatedValidations.push({
        key: I18n.t(`${prefix}.${validation}.key`),
        type: I18n.t(`${prefix}.${validation}.type`),
        description: I18n.t(`${prefix}.${validation}.description`),
      });
    });

    return translatedValidations;
  }
}
