import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { AI_CONVERSATIONS_PANEL } from "../services/ai-conversations-sidebar-manager";

export default class AiBotHeaderIcon extends Component {
  @service appEvents;
  @service currentUser;
  @service sidebarState;
  @service siteSettings;
  @service aiConversationsSidebarManager;

  get bots() {
    const availableBots = this.currentUser.ai_enabled_chat_bots
      .filter((bot) => !bot.is_agent || bot.has_default_llm)
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
    return "far-discobot";
  }

  get clickShouldRouteOutOfConversations() {
    return this.sidebarState.currentPanel?.key === AI_CONVERSATIONS_PANEL;
  }

  get href() {
    if (this.clickShouldRouteOutOfConversations) {
      return getURL(this.aiConversationsSidebarManager.lastKnownAppURL || "/");
    }

    return getURL("/discourse-ai/ai-bot/conversations");
  }

  @action
  onClick() {
    if (!this.clickShouldRouteOutOfConversations) {
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
            class="ai-bot-button icon btn-flat"
            title={{this.title}}
            @action={{unless this.href this.onClick}}
            @href={{this.href}}
            @icon={{this.icon}}
          />
        </PluginOutlet>
      </li>
    {{/if}}
  </template>
}
