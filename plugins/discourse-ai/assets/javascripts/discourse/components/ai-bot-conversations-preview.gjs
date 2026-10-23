import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import AiBotAnonymousCard from "discourse/plugins/discourse-ai/discourse/components/ai-bot-anonymous-card";
import AiBotConversationsLayout from "discourse/plugins/discourse-ai/discourse/components/ai-bot-conversations-layout";
import { storeConversationDraft } from "discourse/plugins/discourse-ai/discourse/lib/ai-bot-conversation-draft";

export default class AiBotConversationsPreview extends Component {
  @service sessionStore;

  @tracked inputValue = "";

  @action
  updateInput(value) {
    this.inputValue = value?.target?.value ?? value;
    storeConversationDraft(this.sessionStore, this.inputValue);
  }

  @action
  handleKeyDown(event) {
    if (event.key === "Enter" && !event.shiftKey && !event.isComposing) {
      event.preventDefault();
      this.showLogin();
    }
  }

  @action
  showLogin() {
    getOwner(this).lookup("route:application").send("showLogin");
  }

  <template>
    <AiBotConversationsLayout
      class="--preview"
      @submit={{this.showLogin}}
      @updateInput={{this.updateInput}}
    >
      <:default>
        <div class="ai-bot-conversations__input-wrapper">
          <textarea
            id="ai-bot-conversations-input"
            placeholder={{i18n "discourse_ai.ai_bot.conversations.placeholder"}}
            rows="1"
            value={{this.inputValue}}
            {{on "input" this.updateInput}}
            {{on "keydown" this.handleKeyDown}}
          />
          <DButton
            class="ai-bot-button btn-transparent ai-conversation-submit"
            @action={{this.showLogin}}
            @icon="paper-plane"
            @title="discourse_ai.ai_bot.conversations.header"
          />
        </div>
      </:default>
      <:footer>
        <AiBotAnonymousCard />
      </:footer>
    </AiBotConversationsLayout>
  </template>
}
