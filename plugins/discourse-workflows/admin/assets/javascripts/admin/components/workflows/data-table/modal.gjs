import Component from "@glimmer/component";
import { action } from "@ember/object";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class DataTableModal extends Component {
  formData = {
    name: this.args.model.dataTable?.name || "",
  };

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
      @title={{if
        @model.dataTable
        (i18n "discourse_workflows.data_tables.edit")
        (i18n "discourse_workflows.data_tables.add")
      }}
      @closeModal={{@closeModal}}
      class="data-table-modal"
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
            @title={{i18n "discourse_workflows.data_tables.name"}}
            @type="input"
            @format="full"
            @validation="required"
            as |field|
          >
            <field.Control
              placeholder={{i18n
                "discourse_workflows.data_tables.name_placeholder"
              }}
            />
          </form.Field>

          <form.Submit />
        </Form>
      </:body>
    </DModal>
  </template>
}
