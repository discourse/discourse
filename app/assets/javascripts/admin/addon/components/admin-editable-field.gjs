import Component from "@ember/component";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";

@tagName("")
export default class AdminEditableField extends Component {
  buffer = "";
  editing = false;

  @action
  edit(event) {
    event?.preventDefault();
    this.set("buffer", this.value);
    this.toggleProperty("editing");
  }

  @action
  save() {
    // Action has to toggle 'editing' property.
    this.action(this.buffer);
  }
}

<div class="field">{{i18n this.name}}</div>
<div class="value">
  {{#if this.editing}}
    <TextField
      @value={{this.buffer}}
      @autofocus="autofocus"
      @autocomplete="off"
    />
  {{else}}
    <a href {{on "click" this.edit}} class="inline-editable-field">
      <span>{{this.value}}</span>
    </a>
  {{/if}}
</div>
<div class="controls">
  {{#if this.editing}}
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