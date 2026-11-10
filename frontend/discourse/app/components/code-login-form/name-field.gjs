import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class CodeLoginNameField extends Component {
  @service siteSettings;

  get showInstructions() {
    return (
      this.siteSettings.show_signup_form_full_name_instructions &&
      !this.args.error
    );
  }

  get instructions() {
    return this.args.required
      ? i18n("user.name.instructions_required")
      : i18n("user.name.instructions");
  }

  <template>
    <div class="code-login-form__name-field">
      <label for="code-login-name">
        {{i18n "user.name.title"}}
      </label>
      <input
        aria-describedby="code-login-name-instructions code-login-name-error"
        aria-invalid={{if @error "true"}}
        autocomplete="name"
        class="code-login-form__name"
        id="code-login-name"
        maxlength="255"
        name="name"
        type="text"
        value={{@value}}
        {{on "input" @onInput}}
      />
      {{#if this.showInstructions}}
        <span
          class="more-info code-login-form__field-instructions"
          id="code-login-name-instructions"
        >
          {{this.instructions}}
        </span>
      {{/if}}
      <div
        aria-live="polite"
        class="code-login-form__error"
        id="code-login-name-error"
        role="alert"
      >
        {{@error}}
      </div>
    </div>
  </template>
}
