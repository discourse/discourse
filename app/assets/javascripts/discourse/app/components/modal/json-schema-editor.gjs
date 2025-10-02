import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { waitForPromise } from "@ember/test-waiters";
import { create } from "virtual-dom";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { iconNode } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";

export default class JsonSchemaEditorModal extends Component {
  @tracked editor = null;
  @tracked value = this.args.model.value;
  @tracked flash;
  @tracked flashType;

  get settingName() {
    return this.args.model.settingName.replace(/\_/g, " ");
  }

  @action
  teardownJsonEditor() {
    this.editor?.destroy();
  }

  @action
  saveChanges() {
    const errors = this.editor.validate();

    if (!errors.length) {
      this.value = JSON.stringify(this.editor.getValue());
      this.args.model.updateValue(this.value);
      this.args.closeModal();
    } else {
      this.flash = errors.map((item) => item.message).join("\n");
      this.flashType = "error";
    }
  }

  @action
  async buildJsonEditor(element) {
    const promise = import("@json-editor/json-editor");
    waitForPromise(promise);
    const { JSONEditor } = await promise;

    JSONEditor.defaults.options.theme = "barebones";
    JSONEditor.defaults.iconlibs = {
      discourseIcons: DiscourseJsonSchemaEditorIconlib,
    };
    JSONEditor.defaults.options.iconlib = "discourseIcons";

    this.editor = new JSONEditor(element, {
      schema: this.args.model.jsonSchema,
      disable_array_delete_all_rows: true,
      disable_array_delete_last_row: true,
      disable_array_reorder: false,
      disable_array_copy: false,
      enable_array_copy: true,
      disable_edit_json: true,
      disable_properties: true,
      disable_collapse: false,
      show_errors: "never",
      startval: this.value ? JSON.parse(this.value) : null,
    });
  }

  <template>
    <DModal
      @flash={{this.flash}}
      @flashType={{this.flashType}}
      @closeModal={{@closeModal}}
      @title={{i18n
        "admin.site_settings.json_schema.modal_title"
        name=@model.settingName
      }}
      @inline={{@inline}}
      class="json-schema-editor-modal"
    >
      <:body>
        <div
          id="json-editor-holder"
          {{didInsert this.buildJsonEditor}}
          {{willDestroy this.teardownJsonEditor}}
        ></div>
      </:body>

      <:footer>
        <DButton
          @action={{this.saveChanges}}
          @label="save"
          class="btn-primary"
        />
      </:footer>
    </DModal>
  </template>
}

class DiscourseJsonSchemaEditorIconlib {
  constructor() {
    this.mapping = {
      delete: "trash-can",
      add: "plus",
      moveup: "arrow-up",
      movedown: "arrow-down",
      moveleft: "chevron-left",
      moveright: "chevron-right",
      copy: "copy",
      collapse: "chevron-down",
      expand: "chevron-up",
    };
  }

  getIcon(key) {
    if (!this.mapping[key]) {
      return;
    }
    return create(iconNode(this.mapping[key]));
  }
}
