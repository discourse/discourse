/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

@tagName("")
export default class SaveControls extends Component {
  @computed("model.isSaving", "saveDisabled")
  get buttonDisabled() {
    return this.model?.isSaving || this.saveDisabled;
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.set("saved", false);
  }

  @computed("model.isSaving")
  get savingText() {
    return this.model?.isSaving ? "saving" : "save";
  }

  <template>
    <div class="controls save-button" ...attributes>
      <DButton
        @action={{this.action}}
        @disabled={{this.buttonDisabled}}
        @label={{this.savingText}}
        class="btn-primary save-changes"
      />
      {{#if this.saved}}
        <span class="saved">{{i18n "saved"}}</span>
      {{/if}}

      {{yield}}
    </div>
  </template>
}
