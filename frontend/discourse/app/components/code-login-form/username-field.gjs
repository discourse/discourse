import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class CodeLoginUsernameField extends Component {
  @service siteSettings;

  get showInstructions() {
    return (
      this.siteSettings.show_signup_form_username_instructions &&
      !this.args.error
    );
  }

  <template>
    <div class="code-login-form__username-field">
      <label for="code-login-username">
        {{i18n "code_login.username_label"}}
      </label>
      <div class="code-login-form__username-input">
        <input
          aria-describedby="code-login-username-instructions code-login-username-error"
          aria-invalid={{if @error "true"}}
          autocomplete={{@autocomplete}}
          class="code-login-form__new-account-username
            {{if @regenerating '--swapping'}}"
          disabled={{@disabled}}
          id="code-login-username"
          name="username"
          placeholder={{i18n "code_login.username_placeholder"}}
          type="text"
          value={{@value}}
          {{on "input" @onInput}}
        />
        {{#if this.siteSettings.enable_random_usernames}}
          <DButton
            aria-busy={{if @regenerating "true"}}
            class="btn-default code-login-form__username-regen
              {{if @regenerating '--rolling'}}"
            @action={{@onRegenerate}}
            @ariaLabel="code_login.regenerate_username"
            @disabled={{@disabled}}
            @icon="dice"
            @title="code_login.regenerate_username"
          />
        {{/if}}
      </div>
      {{#if this.showInstructions}}
        <span
          class="more-info code-login-form__field-instructions"
          id="code-login-username-instructions"
        >
          {{i18n "user.username.instructions"}}
        </span>
      {{/if}}
      <div
        aria-live="polite"
        class="code-login-form__error"
        id="code-login-username-error"
        role="alert"
      >
        {{@error}}
      </div>
    </div>
  </template>
}
