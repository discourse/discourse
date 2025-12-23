/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { or } from "@ember/object/computed";
import { classNames } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

@classNames("controls", "save-button")
export default class SaveControls extends Component {
  @or("model.isSaving", "saveDisabled") buttonDisabled;

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.set("saved", false);
  }

  @computed("model.isSaving")
  get savingText() {
    return this.model?.isSaving ? "saving" : "save";
  }

  <template>
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
  </template>
}
