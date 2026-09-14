import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import valueEntered from "discourse/helpers/value-entered";
import DInputTip from "discourse/ui-kit/d-input-tip";
import DTextField from "discourse/ui-kit/d-text-field";
import { i18n } from "discourse-i18n";

export default class FullnameInput extends Component {
  @service siteSettings;

  get showFullnameInstructions() {
    return (
      this.siteSettings.show_signup_form_full_name_instructions &&
      !this.args.nameValidation.reason
    );
  }

  <template>
    <div ...attributes>
      <DTextField
        aria-describedby="fullname-validation fullname-validation-more-info"
        aria-invalid={{@nameValidation.failed}}
        class={{valueEntered @accountName}}
        name="name"
        @disabled={{@nameDisabled}}
        @id="new-account-name"
        @value={{@accountName}}
        {{on "focusin" @onFocusIn}}
      />
      <label class="alt-placeholder" for="new-account-name">
        {{@nameTitle}}
      </label>

      {{#if this.showFullnameInstructions}}
        <span class="more-info" id="fullname-validation-more-info">
          {{i18n "user.name.instructions_required"}}
        </span>
      {{else}}
        <DInputTip id="fullname-validation" @validation={{@nameValidation}} />
      {{/if}}
    </div>
  </template>
}
