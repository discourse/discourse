import { fn } from "@ember/helper";
import { eq } from "truth-helpers";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

const EMAIL_FREQUENCY_OPTIONS = [
  {
    name: i18n(
      "discourse_policy.preferences.policy_emails.email_frequency_options.never"
    ),
    value: "never",
  },
  {
    name: i18n(
      "discourse_policy.preferences.policy_emails.email_frequency_options.when_away"
    ),
    value: "when_away",
  },
  {
    name: i18n(
      "discourse_policy.preferences.policy_emails.email_frequency_options.always"
    ),
    value: "always",
  },
];

const PreferencesPolicyEmails = <template>
  <h3>{{i18n "discourse_policy.preferences.title"}}</h3>

  <div class="control-group policy-setting controls-dropdown">
    <label for="user_policy_email_frequency">
      {{i18n "discourse_policy.preferences.policy_emails.label"}}
    </label>

    <ComboBox
      @valueProperty="value"
      @content={{EMAIL_FREQUENCY_OPTIONS}}
      @value={{@outletArgs.model.user_option.policy_email_frequency}}
      @onChange={{fn
        (mut @outletArgs.model.user_option.policy_email_frequency)
      }}
      @id="user_policy_email_frequency"
    />

    {{#if (eq @outletArgs.model.user_option.policy_email_frequency "always")}}
      <div class="control-instructions">
        {{i18n "discourse_policy.preferences.policy_emails.always_description"}}
      </div>
    {{else if
      (eq @outletArgs.model.user_option.policy_email_frequency "when_away")
    }}
      <div class="control-instructions">
        {{i18n "discourse_policy.preferences.policy_emails.away_description"}}
      </div>
    {{/if}}
  </div>
</template>;

export default PreferencesPolicyEmails;
