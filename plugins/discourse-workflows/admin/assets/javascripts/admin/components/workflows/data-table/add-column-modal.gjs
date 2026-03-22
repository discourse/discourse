import Component from "@glimmer/component";
import { action } from "@ember/object";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import { i18n } from "discourse-i18n";

export default class AddColumnModal extends Component {
  formData = { name: "", type: "string" };

  @action
  async handleSubmit(data) {
    await this.args.model.onSave(data);
    this.args.closeModal();
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
              <select.Option @value="string">string</select.Option>
              <select.Option @value="number">number</select.Option>
              <select.Option @value="boolean">boolean</select.Option>
              <select.Option @value="date">date</select.Option>
            </field.Control>
          </form.Field>

          <form.Submit />
        </Form>
      </:body>
    </DModal>
  </template>
}
