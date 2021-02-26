import Controller from "@ember/controller";
import { create } from "virtual-dom";
import { iconNode } from "discourse-common/lib/icon-library";
import loadScript from "discourse/lib/load-script";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { schedule } from "@ember/runloop";

export default Controller.extend(ModalFunctionality, {
  editor: null,
  jsonSchema: null,

  onShow() {
    loadScript("/javascripts/jsoneditor.js").then(() => {
      schedule("afterRender", () => {
        const el = document.querySelector("#json-editor-holder");

        JSONEditor.defaults.options.theme = "bootstrap4";

        JSONEditor.defaults.iconlibs = {
          discourseIcons: DiscourseJsonSchemaEditorIconlib,
        };
        JSONEditor.defaults.options.iconlib = "discourseIcons";

        this.editor = new JSONEditor(el, {
          schema: this.model.jsonSchema,
          disable_array_delete_all_rows: true,
          disable_array_delete_last_row: true,
          disable_array_reorder: true,
          disable_array_copy: true,
          disable_edit_json: true,
          disable_properties: true,
          disable_collapse: true,
          startval: this.model.value ? JSON.parse(this.model.value) : null,
        });
      });
    });
  },
});

class DiscourseJsonSchemaEditorIconlib {
  constructor(iconPrefix = "") {
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
