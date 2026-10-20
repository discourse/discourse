import Component from "@glimmer/component";
import PreferenceCheckbox from "discourse/components/preference-checkbox";

export default class AiAskAiDefault extends Component {
  static shouldRender(args, context) {
    const { siteSettings, currentUser } = context;

    return (
      siteSettings.discourse_ai_enabled &&
      siteSettings.ai_ask_ai_enabled &&
      currentUser?.can_use_ask_ai
    );
  }

  <template>
    <fieldset class="control-group ai-preferences">
      {{! saved with the rest of the page rather than on change, unlike the
          toggle offered beside an answer }}
      <PreferenceCheckbox
        class="pref-ai-ask-ai-default"
        data-setting-name="ai-ask-ai-default"
        @checked={{@outletArgs.model.user_option.ai_ask_ai_default}}
        @labelKey="discourse_ai.discobot_discoveries.make_default"
      />
    </fieldset>
  </template>
}
