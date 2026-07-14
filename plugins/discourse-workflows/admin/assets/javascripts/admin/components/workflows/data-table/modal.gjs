import Component from "@glimmer/component";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const NAME_PATTERN = /^[a-zA-Z_][a-zA-Z0-9_ ]*$/;

export default class DataTableModal extends Component {
  formData = {
    name: this.args.model.dataTable?.name || "",
  };

  @action
  validateName(name, value, { addError }) {
    if (value && !NAME_PATTERN.test(value)) {
      addError(name, {
        title: i18n("discourse_workflows.data_tables.name"),
        message: i18n("discourse_workflows.data_tables.name_invalid"),
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
            @validate={{this.validateName}}
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
