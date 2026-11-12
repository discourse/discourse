import AiBotConversations from "discourse/plugins/discourse-ai/discourse/components/ai-bot-conversations";
import AiBotConversationsPreview from "discourse/plugins/discourse-ai/discourse/components/ai-bot-conversations-preview";

export default <template>
  {{#if @controller.showPreview}}
    <AiBotConversationsPreview />
  {{else}}
    <AiBotConversations @controller={{@controller}} />
  {{/if}}
</template>
