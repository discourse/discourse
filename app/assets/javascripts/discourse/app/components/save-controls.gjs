import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";

export default class SaveControls extends Component {
  get buttonDisabled() {
    return this.args.model.isSaving || this.args.saveDisabled;
  }

  get savingText() {
    return this.args.model.isSaving ? "saving" : "save";
  }

  <template>
    <div class="controls save-button">
      <DButton
        @action={{@action}}
        @disabled={{this.buttonDisabled}}
        @label={{this.savingText}}
        class="btn-primary save-changes"
      />

      {{yield}}
    </div>
  </template>
}
