import { apiInitializer } from "discourse/lib/api";
import ChatModalChannelSummary from "../components/modal/chat-modal-channel-summary";

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  const currentUser = api.getCurrentUser();
  const chatService = api.container.lookup("service:chat");
  const modal = api.container.lookup("service:modal");
  const canSummarize = currentUser && currentUser.can_summarize;

  if (
    !siteSettings.chat_enabled ||
    !chatService?.userCanChat ||
    !canSummarize
  ) {
    return;
  }

  api.registerChatComposerButton({
    translatedLabel: "discourse_ai.summarization.chat.title",
    id: "channel-summary",
    icon: "discourse-sparkles",
    position: "dropdown",
    action: () => {
      modal.show(ChatModalChannelSummary, {
        model: { channelId: chatService.activeChannel?.id },
      });
    },
  });
});
