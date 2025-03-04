import Component from "@ember/component";
import { or } from "@ember/object/computed";
import { classNames } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import iN from "discourse/helpers/i18n";
import discourseComputed from "discourse/lib/decorators";

@classNames("controls", "save-button")
export default class SaveControls extends Component {<template><DButton @action={{this.action}} @disabled={{this.buttonDisabled}} @label={{this.savingText}} class="btn-primary save-changes" />
{{#if this.saved}}
  <span class="saved">{{iN "saved"}}</span>
{{/if}}

{{yield}}</template>
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
