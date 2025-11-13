import { fn } from "@ember/helper";
import { eq } from "truth-helpers";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

const EMAIL_FREQUENCY_OPTIONS = [
  { name: i18n("chat.email_frequency.never"), value: "never" },
  { name: i18n("chat.email_frequency.when_away"), value: "when_away" },
];

const PreferencesChatEmails = <template>
  <h3>{{i18n "chat.heading"}}</h3>

  <div
    class="control-group chat-setting controls-dropdown"
    data-setting-name="user_chat_email_frequency"
  >
    <label for="user_chat_email_frequency">
      {{i18n "chat.email_frequency.title"}}
    </label>
    <ComboBox
      @valueProperty="value"
      @content={{EMAIL_FREQUENCY_OPTIONS}}
      @value={{@outletArgs.model.user_option.chat_email_frequency}}
      @id="user_chat_email_frequency"
      @onChange={{fn (mut @outletArgs.model.user_option.chat_email_frequency)}}
    />
    {{#if (eq @outletArgs.model.user_option.chat_email_frequency "when_away")}}
      <div class="control-instructions">
        {{i18n "chat.email_frequency.description"}}
      </div>
    {{/if}}
  </div>
</template>;

export default PreferencesChatEmails;
