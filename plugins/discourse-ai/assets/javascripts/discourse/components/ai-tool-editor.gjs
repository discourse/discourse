import Component from "@glimmer/component";
import { service } from "@ember/service";
import BackButton from "discourse/components/back-button";
import AiToolEditorForm from "./ai-tool-editor-form";

export default class AiToolEditor extends Component {
  @service store;

  get selectedPreset() {
    if (!this.args.selectedPreset) {
      return this.args.presets.findBy("preset_id", "empty_tool");
    }

    return this.args.presets.findBy("preset_id", this.args.selectedPreset);
  }

  get editingModel() {
    if (this.args.model.isNew) {
      return this.store.createRecord("ai-tool", this.selectedPreset);
    } else {
      return this.args.model;
    }
  }

  <template>
    <BackButton
      @route="adminPlugins.show.discourse-ai-tools"
      @label="discourse_ai.tools.back"
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
