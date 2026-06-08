import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { showShareConversationModal } from "../lib/ai-bot-helper";

export default class AiConversationSidebarContextMenu extends Component {
  @service currentUser;
  @service modal;

  @tracked isTogglingStarred = false;

  get topic() {
    return this.args.data.topic;
  }

  get manager() {
    return this.args.data.manager;
  }

  get canStarConversations() {
    return this.manager.siteSettings.enable_ai_bot_starred_conversations;
  }

  get canShare() {
    return this.currentUser?.can_share_ai_bot_conversations;
  }

  get isStarred() {
    return !!this.topic?.ai_conversation_starred;
  }

  get starIcon() {
    return this.isStarred ? "star" : "far-star";
  }

  get starLabel() {
    return this.isStarred
      ? "discourse_ai.ai_bot.conversations.unstar_conversation"
      : "discourse_ai.ai_bot.conversations.star_conversation";
  }

  @action
  async toggleStarred() {
    if (!this.canStarConversations || !this.topic || this.isTogglingStarred) {
      return;
    }

    this.isTogglingStarred = true;

    try {
      await this.manager.updateConversationStarred(this.topic, !this.isStarred);
      this.args.close();
    } finally {
      this.isTogglingStarred = false;
    }
  }

  @action
  share() {
    if (!this.canShare || !this.topic) {
      return;
    }

    showShareConversationModal(this.modal, this.topic.id);
    this.args.close();
  }

  <template>
    <DDropdownMenu class="ai-conversation-sidebar-link-menu" as |dropdown|>
      {{#if this.canStarConversations}}
        <dropdown.item>
          <DButton
            @action={{this.toggleStarred}}
            @disabled={{this.isTogglingStarred}}
            @icon={{this.starIcon}}
            @label={{this.starLabel}}
            @title={{this.starLabel}}
            class="ai-conversation-sidebar-link-menu__star-conversation"
          />
        </dropdown.item>
      {{/if}}
      {{#if this.canShare}}
        <dropdown.item>
          <DButton
            @action={{this.share}}
            @icon="share-nodes"
            @label="discourse_ai.ai_bot.share_ai_conversation.name"
            @title="discourse_ai.ai_bot.share_ai_conversation.title"
            class="ai-conversation-sidebar-link-menu__share-conversation"
          />
        </dropdown.item>
      {{/if}}
    </DDropdownMenu>
  </template>
}
