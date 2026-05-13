import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";

export default class AiConversationSidebarContextMenu extends Component {
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
    </DDropdownMenu>
  </template>
}
