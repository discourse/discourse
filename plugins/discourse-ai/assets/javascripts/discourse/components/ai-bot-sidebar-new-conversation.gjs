import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import BackToForum from "discourse/components/sidebar/back-to-forum";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import { AI_CONVERSATIONS_PANEL } from "../services/ai-conversations-sidebar-manager.js";
import AiBotAnonymousCard from "./ai-bot-anonymous-card.gjs";

export default class AiBotSidebarNewConversation extends Component {
  @service aiConversationsSidebarManager;
  @service currentUser;
  @service mobileTabBar;
  @service sidebarState;
  @service siteSettings;

  // The tab bar's menu leads with its own action, and its tabs lead back
  get shouldRender() {
    return (
      !this.mobileTabBar.enabled &&
      this.sidebarState.isCurrentPanel(AI_CONVERSATIONS_PANEL)
    );
  }

  get shouldShowBackLink() {
    return !this.siteSettings.ai_bot_add_to_header;
  }

  get backToForumHref() {
    return getURL(this.aiConversationsSidebarManager.lastKnownAppURL || "/");
  }

  @action
  routeTo() {
    this.aiConversationsSidebarManager.startNewConversation();
    this.args.outletArgs?.toggleNavigationMenu?.();
  }

  <template>
    {{#if this.shouldRender}}
      {{#if this.shouldShowBackLink}}
        <BackToForum @href={{this.backToForumHref}} />
      {{/if}}
      {{#if this.currentUser}}
        <div class="ai-new-question-button__wrapper">
          <DButton
            class="ai-new-question-button btn-default"
            @action={{this.routeTo}}
            @icon="plus"
            @label="discourse_ai.ai_bot.conversations.new"
          />
        </div>
      {{else}}
        <AiBotAnonymousCard />
      {{/if}}
    {{/if}}
  </template>
}
