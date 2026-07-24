import Component from "@glimmer/component";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const COLUMN_NAME_PATTERN = /^[a-zA-Z_][a-zA-Z0-9_]*$/;

export default class AddColumnModal extends Component {
  formData = { name: "", type: "string" };

  @action
  validateColumnName(name, value, { addError }) {
    if (value && !COLUMN_NAME_PATTERN.test(value)) {
      addError(name, {
        title: i18n("discourse_workflows.data_tables.column_name"),
        message: i18n("discourse_workflows.data_tables.column_name_invalid"),
      });
    }
  }

  @action
  async handleSubmit(data) {
    try {
      await this.args.model.onSave(data);
      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DModal
      @title={{i18n "discourse_workflows.data_tables.add_column"}}
      @closeModal={{@closeModal}}
      class="data-table-add-column-modal"
    >
      <:body>
        <Form
          @data={{this.formData}}
          @onSubmit={{this.handleSubmit}}
          class="workflows-configurator-form"
          as |form|
        >
          <form.Field
            @name="name"
            @title={{i18n "discourse_workflows.data_tables.column_name"}}
            @type="input"
            @format="full"
            @validation="required"
            @validate={{this.validateColumnName}}
            as |field|
          >
            <field.Control placeholder="column_name" />
          </form.Field>

          <form.Field
            @name="type"
            @title={{i18n "discourse_workflows.data_tables.column_type"}}
            @type="select"
            @format="full"
            @validation="required"
            as |field|
          >
            <field.Control as |select|>
              <select.Option @value="string">{{i18n
                  "discourse_workflows.data_tables.column_types.string"
                }}</select.Option>
              <select.Option @value="number">{{i18n
                  "discourse_workflows.data_tables.column_types.number"
                }}</select.Option>
              <select.Option @value="boolean">{{i18n
                  "discourse_workflows.data_tables.column_types.boolean"
                }}</select.Option>
              <select.Option @value="date">{{i18n
                  "discourse_workflows.data_tables.column_types.date"
                }}</select.Option>
            </field.Control>
          </form.Field>

          <form.Submit />
        </Form>
      </:body>
    </DModal>
  </template>
}
