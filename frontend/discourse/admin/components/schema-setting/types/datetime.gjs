import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FieldInputDescription from "discourse/admin/components/schema-setting/field-input-description";
import { and, not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class SchemaSettingTypeDatetime extends Component {
  @tracked touched = false;
  @tracked value = this.args.value || "";
  @tracked
  localTime = this.args.value
    ? moment(this.args.value).local().format(moment.HTML5_FMT.DATETIME_LOCAL)
    : "";
  required = this.args.spec.required;

  @action
  onInput(event) {
    this.touched = true;
    const datetime = event.currentTarget.value;
    this.localTime = datetime;

    if (!datetime) {
      this.args.onChange("");
      this.value = "";
      return;
    }

    // Convert to UTC ISO string for storage
    const utcValue = moment(datetime).utc().format();
    this.args.onChange(utcValue);
    this.value = utcValue;
  }

  get validationErrorMessage() {
    if (!this.touched) {
      return;
    }

    if (this.value.length === 0 && this.required) {
      return i18n("admin.customize.schema.fields.required");
    }
  }

  <template>
    <Input
      @type="datetime-local"
      class="--datetime"
      @value={{this.localTime}}
      {{on "input" this.onInput}}
      required={{this.required}}
    />

    <div class="schema-field__input-supporting-text">
      {{#if (and @description (not this.validationErrorMessage))}}
        <FieldInputDescription @description={{@description}} />
      {{/if}}

      {{#if this.validationErrorMessage}}
        <div class="schema-field__input-error">
          {{this.validationErrorMessage}}
        </div>
      {{/if}}
    </div>
  </template>
}
