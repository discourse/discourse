import BaseField from "./da-base-field";
import { action } from "@ember/object";

export default class KeyValueField extends BaseField {
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

  get value() {
    return (
      this.get("field.metadata.value") ||
      '[{"key":"example","value":"You posted %%KEY%%"}]'
    );
  }

  get keyCount() {
    if (this.get("field.metadata.value")) {
      return JSON.parse(this.value).length;
    }

    return 0;
  }

  @action
  handleValueChange(value) {
    if (value !== this.field.metadata.value) {
      this.set("field.metadata.value", value);
      this.saveAutomation();
    }
  }
}
