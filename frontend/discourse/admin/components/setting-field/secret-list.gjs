import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import SecretValueList from "discourse/admin/components/secret-value-list";
import showFieldError from "discourse/admin/lib/show-field-error";
import DButton from "discourse/ui-kit/d-button";

export default class SettingFieldSecretList extends Component {
  @tracked isRevealed = false;

  get isMasked() {
    return this.args.definition.secret && !this.isRevealed;
  }

  @action
  toggleMask() {
    this.isRevealed = !this.isRevealed;
  }

  <template>
    <@field.Control>
      <SecretValueList
        @changeValueCallback={{@field.set}}
        @isSecret={{this.isMasked}}
        @placeholder={{@definition.placeholder}}
        @setValidationMessage={{fn showFieldError @field}}
        @values={{@field.value}}
      />
    </@field.Control>

    {{#if @definition.secret}}
      <DButton
        class="btn-default setting-toggle-secret"
        @action={{this.toggleMask}}
        @ariaLabel="admin.settings.unmask"
        @icon={{if this.isMasked "far-eye" "far-eye-slash"}}
      />
    {{/if}}
  </template>
}
