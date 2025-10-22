import Component from "@glimmer/component";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

const TABLE_HEADER_KEYS = ["key", "type", "description"];
const VALIDATION_KEYS = ["required", "minimum", "maximum", "pattern", "type"];

export default class FormTemplateValidationOptions extends Component {
  get tableHeaders() {
    const translatedHeaders = [];
    TABLE_HEADER_KEYS.forEach((header) => {
      translatedHeaders.push(
        i18n(`admin.form_templates.validations_modal.table_headers.${header}`)
      );
    });

    return translatedHeaders;
  }

  get validations() {
    const translatedValidations = [];
    const prefix = "admin.form_templates.validations_modal.validations";
    VALIDATION_KEYS.forEach((validation) => {
      translatedValidations.push({
        key: i18n(`${prefix}.${validation}.key`),
        type: i18n(`${prefix}.${validation}.type`),
        description: i18n(`${prefix}.${validation}.description`),
      });
    });

    return translatedValidations;
  }

  <template>
    <DModal
      class="form-templates__validation-options admin-form-template-validation-options-modal"
      @title={{i18n "admin.form_templates.validations_modal.modal_title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <table>
          <thead>
            <tr>
              {{#each this.tableHeaders as |header|}}
                <th>{{header}}</th>
              {{/each}}
            </tr>
          </thead>
          <tbody>
            {{#each this.validations as |item|}}
              <tr>
                <td><pre>{{item.key}}</pre></td>
                <td>{{item.type}}</td>
                <td>{{item.description}}</td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </:body>
    </DModal>
  </template>
}
