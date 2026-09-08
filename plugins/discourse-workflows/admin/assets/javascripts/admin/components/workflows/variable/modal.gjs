import Component from "@glimmer/component";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const KEY_PATTERN = /^[a-zA-Z_][a-zA-Z0-9_]*$/;

export default class VariableModal extends Component {
  formData = {
    key: this.args.model.variable?.key || "",
    value: this.args.model.variable?.value || "",
  };

  @action
  validateKey(name, value, { addError }) {
    if (value && !KEY_PATTERN.test(value)) {
      addError(name, {
        title: i18n("discourse_workflows.variables.key"),
        message: i18n("discourse_workflows.variables.key_invalid"),
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
      @closeModal={{@closeModal}}
      @title={{if
        @model.variable
        (i18n "discourse_workflows.variables.edit")
        (i18n "discourse_workflows.variables.add")
      }}
    >
      <:body>
        <Form
          class="workflows-configurator-form"
          @data={{this.formData}}
          @onSubmit={{this.handleSubmit}}
          as |form|
        >
          <form.Field
            @format="full"
            @name="key"
            @title={{i18n "discourse_workflows.variables.key"}}
            @type="input"
            @validate={{this.validateKey}}
            @validation="required"
            as |field|
          >
            <field.Control
              placeholder={{i18n
                "discourse_workflows.variables.key_placeholder"
              }}
            />
          </form.Field>

          <form.Field
            @format="full"
            @name="value"
            @title={{i18n "discourse_workflows.variables.value"}}
            @type="input"
            @validation="required"
            as |field|
          >
            <field.Control
              placeholder={{i18n
                "discourse_workflows.variables.value_placeholder"
              }}
            />
          </form.Field>

          <form.Submit />
        </Form>
      </:body>
    </DModal>
  </template>
}
