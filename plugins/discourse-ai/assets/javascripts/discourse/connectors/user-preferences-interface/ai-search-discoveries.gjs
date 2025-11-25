import Component from "@glimmer/component";
import PreferenceCheckbox from "discourse/components/preference-checkbox";

export default class AiSearchDiscoveries extends Component {
  static shouldRender(args, context) {
    const { siteSettings, currentUser } = context;
    return (
      siteSettings.discourse_ai_enabled &&
      siteSettings.ai_discover_enabled &&
      siteSettings.ai_discover_persona &&
      currentUser?.can_use_ai_discover_persona
    );
  }

  <template>
    <fieldset class="control-group ai-preferences">
      <PreferenceCheckbox
        @labelKey="discourse_ai.discobot_discoveries.user_setting"
        @checked={{@outletArgs.model.user_option.ai_search_discoveries}}
        data-setting-name="ai-search-discoveries"
        class="pref-ai-search-discoveries"
      />
    </fieldset>
  </template>
}
