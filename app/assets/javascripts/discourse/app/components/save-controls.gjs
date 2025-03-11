import Component from "@ember/component";
import { or } from "@ember/object/computed";
import { classNames } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";

@classNames("controls", "save-button")
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
}
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