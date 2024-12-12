import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import InputTip from "discourse/components/input-tip";
import TextField from "discourse/components/text-field";
import valueEntered from "discourse/helpers/value-entered";
import { i18n } from "discourse-i18n";

export default class SidebarEditNavigationMenuTagsModal extends Component {
  @service siteSettings;

  get showFullname() {
    return (
      this.siteSettings.full_name_required || this.siteSettings.enable_names
    );
  }

  get showFullnameInstructions() {
    return (
      this.siteSettings.show_signup_form_full_name_instructions &&
      !this.args.nameValidation.reason
    );
  }

  <template>
    <div ...attributes>
      <TextField
        {{on "focusin" @onFocusIn}}
        @disabled={{@nameDisabled}}
        @value={{@accountName}}
        @id="new-account-name"
        aria-describedby="fullname-validation fullname-validation-more-info"
        aria-invalid={{@nameValidation.failed}}
        class={{valueEntered @accountName}}
        name="name"
      />
      <label class="alt-placeholder" for="new-account-name">
        {{@nameTitle}}
      </label>

      {{#if this.showFullnameInstructions}}
        <span class="more-info" id="fullname-validation-more-info">
          {{i18n "user.name.instructions_required"}}
        </span>
      {{else}}
        <InputTip @validation={{@nameValidation}} id="fullname-validation" />
      {{/if}}
    </div>
  </template>
}
