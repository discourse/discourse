import { action } from "@ember/object";
import Component from "@ember/component";
import showModal from "discourse/lib/show-modal";

export default Component.extend({
  tagName: "",

  @action
  launchJsonEditorModal() {
    const schemaModal = showModal("json-schema-editor", {
      model: {
        value: this.value,
        settingName: this.setting.setting,
        jsonSchema: this.setting.json_schema,
      },
    });

    schemaModal.set("onClose", () => {
      this.set("value", schemaModal.model.value);
    });
  }
});
