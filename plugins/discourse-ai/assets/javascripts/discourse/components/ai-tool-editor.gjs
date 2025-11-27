import Component from "@glimmer/component";
import { service } from "@ember/service";
import DPageSubheader from "discourse/components/d-page-subheader";
import { i18n } from "discourse-i18n";
import AiToolEditorForm from "./ai-tool-editor-form";

export default class AiToolEditor extends Component {
  @service store;

  get selectedPreset() {
    if (!this.args.selectedPreset) {
      return this.args.presets.find((item) => item.preset_id === "empty_tool");
    }

    return this.args.presets.find(
      (item) => item.preset_id === this.args.selectedPreset
    );
  }

  get editingModel() {
    if (this.args.model.isNew) {
      return this.store.createRecord("ai-tool", this.selectedPreset);
    } else {
      return this.args.model;
    }
  }

  <template>
    <DPageSubheader
      @titleLabel={{if
        @model.isNew
        (i18n "discourse_ai.tools.new_tool")
        (i18n "discourse_ai.tools.edit_tool")
      }}
    />

    <AiToolEditorForm
      @model={{@model}}
      @tools={{@tools}}
      @editingModel={{this.editingModel}}
      @isNew={{@model.isNew}}
      @selectedPreset={{this.selectedPreset}}
    />
  </template>
}
