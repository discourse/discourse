import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DTextField from "discourse/ui-kit/d-text-field";
import { i18n } from "discourse-i18n";

export default class AdminEditableField extends Component {
  @tracked buffer = "";

  @action
  edit(event) {
    event?.preventDefault();
    this.buffer = this.args.value;
    this.args.toggleEditing();
  }

  @action
  save() {
    // Saving is what leaves edit mode, so the caller toggles `editing` too.
    this.args.action(this.buffer);
  }

  <template>
    <div class="field">{{i18n @name}}</div>
    <div class="value">
      {{#if @editing}}
        <DTextField
          @autocomplete="off"
          @autofocus="autofocus"
          @value={{this.buffer}}
        />
      {{else}}
        <a class="inline-editable-field" href {{on "click" this.edit}}>
          <span>{{@value}}</span>
        </a>
      {{/if}}
    </div>
    <div class="controls">
      {{#if @editing}}
        <DButton
          class="btn-default"
          @action={{this.save}}
          @label="admin.user_fields.save"
        />
        <a href {{on "click" this.edit}}>{{i18n "cancel"}}</a>
      {{else}}
        <DButton class="btn-default" @action={{this.edit}} @icon="pencil" />
      {{/if}}
    </div>
  </template>
}
