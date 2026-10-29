import AiBotConversations from "discourse/plugins/discourse-ai/discourse/components/ai-bot-conversations";
import AiBotConversationsPreview from "discourse/plugins/discourse-ai/discourse/components/ai-bot-conversations-preview";
import AiBotMobileConversationList from "discourse/plugins/discourse-ai/discourse/components/ai-bot-mobile-conversation-list";

export default <template>
  {{#if @controller.showPreview}}
    <AiBotConversationsPreview />
  {{else}}
    <div class="ai-bot-conversations-index">
      <AiBotConversations @controller={{@controller}} />
      <AiBotMobileConversationList />
    </div>
  {{/if}}
</template>
