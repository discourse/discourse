import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import { composeAiBotMessage } from "../lib/ai-bot-helper";
import { AI_CONVERSATIONS_PANEL } from "../services/ai-conversations-sidebar-manager";

export default class AiBotHeaderIcon extends Component {
  @service appEvents;
  @service composer;
  @service currentUser;
  @service navigationMenu;
  @service sidebarState;
  @service siteSettings;
  @service aiConversationsSidebarManager;

  get bots() {
    const availableBots = this.currentUser.ai_enabled_chat_bots
      .filter((bot) => !bot.is_persona || bot.has_default_llm)
      .filter(Boolean);

    return availableBots ? availableBots.map((bot) => bot.model_name) : [];
  }

  get showHeaderButton() {
    return this.bots.length > 0 && this.siteSettings.ai_bot_add_to_header;
  }

  get title() {
    if (this.clickShouldRouteOutOfConversations) {
      return i18n("discourse_ai.ai_bot.exit");
    }

    return i18n("discourse_ai.ai_bot.shortcut_title");
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

  get href() {
    if (this.clickShouldRouteOutOfConversations) {
      return getURL(this.aiConversationsSidebarManager.lastKnownAppURL || "/");
    }

    if (this.siteSettings.ai_bot_enable_dedicated_ux) {
      return getURL("/discourse-ai/ai-bot/conversations");
    }

    return null;
  }

  @action
  onClick() {
    if (!this.siteSettings.ai_bot_enable_dedicated_ux) {
      composeAiBotMessage(this.bots[0], this.composer);
    }

    if (
      this.siteSettings.ai_bot_enable_dedicated_ux &&
      !this.clickShouldRouteOutOfConversations
    ) {
      this.appEvents.trigger("discourse-ai:bot-header-icon-clicked");
    }
  }

  <template>
    {{#if this.showHeaderButton}}
      <li>
        <PluginOutlet
          @name="ai-bot-header-icon"
          @outletArgs={{lazyHash onClick=this.onClick icon=this.icon}}
        >
          <DButton
            @href={{this.href}}
            @action={{unless this.href this.onClick}}
            @icon={{this.icon}}
            title={{this.title}}
            class="ai-bot-button icon btn-flat"
          />
        </PluginOutlet>
      </li>
    {{/if}}
  </template>
}
