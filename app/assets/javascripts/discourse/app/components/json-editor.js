import { action } from "@ember/object";
import Component from "@ember/component";
import { create } from "virtual-dom";
import discourseComputed from "discourse-common/utils/decorators";
import { iconNode } from "discourse-common/lib/icon-library";
import loadScript from "discourse/lib/load-script";
import { schedule } from "@ember/runloop";

export default Component.extend({
  className: "json-editor-holder",
  editor: null,
  saveChangesCallback: null,

  didInsertElement() {
    this._super(...arguments);

    loadScript("/javascripts/jsoneditor.js").then(() => {
      schedule("afterRender", () => {
        let { JSONEditor } = window;

        JSONEditor.defaults.options.theme = "bootstrap4";
        JSONEditor.defaults.iconlibs = {
          discourseIcons: DiscourseJsonSchemaEditorIconlib,
        };
        JSONEditor.defaults.options.iconlib = "discourseIcons";

        const el = document.querySelector("#json-editor-holder");
        this.editor = new JSONEditor(el, {
          schema: this.model.jsonSchema,
          disable_array_delete_all_rows: true,
          disable_array_delete_last_row: true,
          disable_array_reorder: true,
          disable_array_copy: true,
          disable_edit_json: true,
          disable_properties: true,
          disable_collapse: true,
          show_errors: "never",
          startval: this.model.value ? JSON.parse(this.model.value) : null,
        });
      });
    });
  },

  @discourseComputed("model.settingName")
  settingName(name) {
    return name.replace(/\_/g, " ");
  },

  @action
  saveChanges() {
    const errors = this.editor.validate();
    if (!errors.length) {
      const fieldValue = JSON.stringify(this.editor.getValue());
      this?.saveChangesCallback(fieldValue);
    } else {
      this.appEvents.trigger("modal-body:flash", {
        text: errors.mapBy("message").join("\n"),
        messageClass: "error",
      });
    }
  },

  willDestroyElement() {
    this._super(...arguments);

    this.editor?.destroy();
  },
});

class DiscourseJsonSchemaEditorIconlib {
  constructor() {
    this.mapping = {
      delete: "times",
      add: "plus",
    };
  }

  getIcon(key) {
    if (!this.mapping[key]) {
      return;
    }
    return create(iconNode(this.mapping[key]));
  }
}
