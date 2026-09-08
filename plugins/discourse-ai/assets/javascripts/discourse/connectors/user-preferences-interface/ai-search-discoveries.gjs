import Component from "@glimmer/component";
import PreferenceCheckbox from "discourse/components/preference-checkbox";

export default class AiSearchDiscoveries extends Component {
  static shouldRender(args, context) {
    const { siteSettings, currentUser } = context;
    return (
      siteSettings.discourse_ai_enabled &&
      siteSettings.ai_discover_enabled &&
      siteSettings.ai_discover_agent &&
      currentUser?.can_use_ai_discover_agent
    );
  }

  <template>
    <fieldset class="control-group ai-preferences">
      <PreferenceCheckbox
        class="pref-ai-search-discoveries"
        data-setting-name="ai-search-discoveries"
        @checked={{@outletArgs.model.user_option.ai_search_discoveries}}
        @labelKey="discourse_ai.discobot_discoveries.user_setting"
      />
    </fieldset>
  </template>
}
