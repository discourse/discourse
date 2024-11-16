import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import InputTip from "discourse/components/input-tip";
import TextField from "discourse/components/text-field";
import valueEntered from "discourse/helpers/value-entered";

export default class SidebarEditNavigationMenuTagsModal extends Component {
  get showFullname() {
    return (
      this.siteSettings.full_name_required || this.siteSettings.enable_names
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

      <InputTip @validation={{@nameValidation}} id="fullname-validation" />
    </div>
  </template>
}
