import showModal from "discourse/lib/show-modal";
import BaseField from "./da-base-field";
import { action } from "@ember/object";

export default BaseField.extend({
  @action
  openSchemaModal() {
    const jsonSchemaEditorModal = showModal("json-schema-editor", {
      model: {
        value:
          this.field.metadata.value ||
          '[{"key":"example","value":"You posted %%KEY%%"}]',
        settingName: this.label,
        jsonSchema: {
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
        },
      },
    });

    jsonSchemaEditorModal.set("onClose", () => {
      if (jsonSchemaEditorModal.model.value !== this.field.metadata.value) {
        this.set("field.metadata.value", jsonSchemaEditorModal.model.value);
        this.saveAutomation();
      }
    });
  },
});
