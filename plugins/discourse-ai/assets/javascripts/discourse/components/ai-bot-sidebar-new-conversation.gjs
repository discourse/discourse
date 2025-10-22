import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import BackToForum from "discourse/components/sidebar/back-to-forum";
import { AI_CONVERSATIONS_PANEL } from "../services/ai-conversations-sidebar-manager";

const TEXTAREA_ID = "ai-bot-conversations-input";

export default class AiBotSidebarNewConversation extends Component {
  @service appEvents;
  @service router;
  @service sidebarState;
  @service siteSettings;

  get shouldRender() {
    return this.sidebarState.isCurrentPanel(AI_CONVERSATIONS_PANEL);
  }

  get shouldShowBackLink() {
    return !this.siteSettings.ai_bot_add_to_header;
  }

  @action
  focusTextarea() {
    document.getElementById(TEXTAREA_ID)?.focus();
  }

  @action
  routeTo() {
    this.appEvents.trigger("discourse-ai:new-conversation-btn-clicked");

    if (this.router.currentRouteName !== "discourse-ai-bot-conversations") {
      this.router.transitionTo("/discourse-ai/ai-bot/conversations");
    } else {
      this.focusTextarea();
    }

    this.args.outletArgs?.toggleNavigationMenu?.();
  }

  <template>
    {{#if this.shouldRender}}
      {{#if this.shouldShowBackLink}}
        <BackToForum />
      {{/if}}
      <div class="ai-new-question-button__wrapper">
        <DButton
          @label="discourse_ai.ai_bot.conversations.new"
          @icon="plus"
          @action={{this.routeTo}}
          class="ai-new-question-button btn-default"
        />
      </div>
    {{/if}}
  </template>
}
