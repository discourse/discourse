import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import ModalJsonSchemaEditor from "discourse/components/modal/json-schema-editor";
import { i18n } from "discourse-i18n";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class KeyValueField extends BaseField {
  @tracked showJsonEditorModal = false;

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
        <DAFieldLabel @label={{@label}} @field={{@field}} />

        <div class="controls">
          <DButton class="configure-btn" @action={{this.openModal}}>
            {{this.showJsonModalLabel}}
          </DButton>

          {{#if this.showJsonEditorModal}}
            <ModalJsonSchemaEditor
              @model={{hash
                value=this.value
                updateValue=this.handleValueChange
                settingName=@label
                jsonSchema=this.jsonSchema
              }}
              @closeModal={{this.closeModal}}
            />
          {{/if}}

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
  handleValueChange(value) {
    if (value !== this.args.field.metadata.value) {
      this.mutValue(value);
      this.args.saveAutomation();
    }
  }

  @action
  openModal() {
    this.showJsonEditorModal = true;
  }

  @action
  closeModal() {
    this.showJsonEditorModal = false;
  }
}
