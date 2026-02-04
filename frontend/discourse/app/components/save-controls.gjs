/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { or } from "@ember/object/computed";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

@tagName("")
export default class SaveControls extends Component {
  @or("model.isSaving", "saveDisabled") buttonDisabled;

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.set("saved", false);
  }

  @discourseComputed("model.isSaving")
  savingText(saving) {
    return saving ? "saving" : "save";
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
