import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { defaultHomepage } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import { composeAiBotMessage } from "../lib/ai-bot-helper";
import { AI_CONVERSATIONS_PANEL } from "../services/ai-conversations-sidebar-manager";

export default class AiBotHeaderIcon extends Component {
  @service appEvents;
  @service composer;
  @service currentUser;
  @service navigationMenu;
  @service router;
  @service sidebarState;
  @service siteSettings;

  get bots() {
    const availableBots = this.currentUser.ai_enabled_chat_bots
      .filter((bot) => !bot.is_persona || bot.has_default_llm)
      .filter(Boolean);

    return availableBots ? availableBots.map((bot) => bot.model_name) : [];
  }

  get showHeaderButton() {
    return this.bots.length > 0 && this.siteSettings.ai_bot_add_to_header;
  }

  get icon() {
    if (this.clickShouldRouteOutOfConversations) {
      return "shuffle";
    }
    return "robot";
  }

  get clickShouldRouteOutOfConversations() {
    return (
      !this.navigationMenu.isHeaderDropdownMode &&
      this.siteSettings.ai_bot_enable_dedicated_ux &&
      this.sidebarState.currentPanel?.key === AI_CONVERSATIONS_PANEL
    );
  }

  @action
  onClick() {
    if (this.clickShouldRouteOutOfConversations) {
      return this.router.transitionTo(`discovery.${defaultHomepage()}`);
    }

    if (this.siteSettings.ai_bot_enable_dedicated_ux) {
      this.appEvents.trigger("discourse-ai:bot-header-icon-clicked");
      return this.router.transitionTo("discourse-ai-bot-conversations");
    }

    composeAiBotMessage(this.bots[0], this.composer);
  }

  <template>
    {{#if this.showHeaderButton}}
      <li>
        <PluginOutlet
          @name="ai-bot-header-icon"
          @outletArgs={{lazyHash onClick=this.onClick icon=this.icon}}
        >
          <DButton
            @action={{this.onClick}}
            @icon={{this.icon}}
            title={{i18n "discourse_ai.ai_bot.shortcut_title"}}
            class="ai-bot-button icon btn-flat"
          />
        </PluginOutlet>
      </li>
    {{/if}}
  </template>
}
