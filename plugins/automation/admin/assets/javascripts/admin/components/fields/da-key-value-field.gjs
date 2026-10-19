import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import BaseField from "./da-base-field.gjs";
import DAFieldDescription from "./da-field-description.gjs";
import DAFieldLabel from "./da-field-label.gjs";

export default class KeyValueField extends BaseField {
  @service modal;

  jsonSchema = {
    type: "array",
    uniqueItems: true,
    items: {
      type: "object",
      title: "group",
      properties: {
        key: {
          type: "string",
        },
        value: {
          type: "string",
          format: "textarea",
        },
      },
    },
  };

  <template>
    <section class="field key-value-field">
      <div class="control-group">
        <DAFieldLabel @field={{@field}} @label={{@label}} />

        <div class="controls">
          <DButton class="configure-btn" @action={{this.openModal}}>
            {{this.showJsonModalLabel}}
          </DButton>

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>

  get value() {
    return (
      this.args.field.metadata.value ||
      '[{"key":"example","value":"You posted {{key}}"}]'
    );
  }

  get keyCount() {
    if (this.args.field.metadata.value) {
      return JSON.parse(this.value).length;
    }

    return 0;
  }

  get showJsonModalLabel() {
    if (this.keyCount === 0) {
      return i18n("discourse_automation.fields.key_value.label_without_count");
    } else {
      return i18n("discourse_automation.fields.key_value.label_with_count", {
        count: this.keyCount,
      });
    }
  }

  @action
  openModal() {
    this.modal.show(import("discourse/components/modal/json-schema-editor"), {
      model: {
        value: this.value,
        updateValue: this.mutValue,
        settingName: this.args.label,
        jsonSchema: this.jsonSchema,
      },
    });
  }
}
