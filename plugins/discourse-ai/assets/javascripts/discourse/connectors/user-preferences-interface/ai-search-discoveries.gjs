import Component from "@glimmer/component";
import { service } from "@ember/service";
import PreferenceCheckbox from "discourse/components/preference-checkbox";

export default class AiSearchDiscoveries extends Component {
  static shouldRender(args, context) {
    const { siteSettings, currentUser } = context;

    const showDiscoveries =
      siteSettings.ai_discover_enabled &&
      siteSettings.ai_discover_agent &&
      currentUser?.can_use_ai_discover_agent;

    const showSendOnEnter = siteSettings.ai_bot_enable_docked_composer;

    return (
      siteSettings.discourse_ai_enabled && (showDiscoveries || showSendOnEnter)
    );
  }

  @service siteSettings;
  @service currentUser;

  get showDiscoveries() {
    return (
      this.siteSettings.ai_discover_enabled &&
      this.siteSettings.ai_discover_agent &&
      this.currentUser?.can_use_ai_discover_agent
    );
  }

  get showSendOnEnter() {
    return this.siteSettings.ai_bot_enable_docked_composer;
  }

  <template>
    <fieldset class="control-group ai-preferences">
      {{#if this.showDiscoveries}}
        <PreferenceCheckbox
          @labelKey="discourse_ai.discobot_discoveries.user_setting"
          @checked={{@outletArgs.model.user_option.ai_search_discoveries}}
          data-setting-name="ai-search-discoveries"
          class="pref-ai-search-discoveries"
        />
      {{/if}}
      {{#if this.showSendOnEnter}}
        <PreferenceCheckbox
          @labelKey="discourse_ai.ai_bot.conversations.send_on_enter_setting"
          @checked={{@outletArgs.model.user_option.ai_conversations_send_on_enter}}
          data-setting-name="ai-conversations-send-on-enter"
          class="pref-ai-conversations-send-on-enter"
        />
      {{/if}}
    </fieldset>
  </template>
}
