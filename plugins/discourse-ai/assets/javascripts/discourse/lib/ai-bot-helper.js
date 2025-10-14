import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import ShareFullTopicModal from "../components/modal/share-full-topic-modal";

const MAX_PERSONA_USER_ID = -1200;

let enabledChatBotMap = null;

function ensureBotMap() {
  if (!enabledChatBotMap) {
    const currentUser = getOwnerWithFallback(this).lookup(
      "service:current-user"
    );
    enabledChatBotMap = {};
    currentUser.ai_enabled_chat_bots.forEach((bot) => {
      enabledChatBotMap[bot.id] = bot;
    });
  }
}

export function isGPTBot(user) {
  if (!user) {
    return;
  }

  ensureBotMap();
  return !!enabledChatBotMap[user.id];
}

export function getBotType(user) {
  if (!user) {
    return;
  }

  ensureBotMap();
  const bot = enabledChatBotMap[user.id];
  if (!bot) {
    return;
  }
  return bot.is_persona ? "persona" : "llm";
}

export function isPostFromAiBot(post, currentUser) {
  return (
    post.user_id <= MAX_PERSONA_USER_ID ||
    !!currentUser?.ai_enabled_chat_bots?.some(
      (bot) => post.username === bot.username
    )
  );
}

export function showShareConversationModal(modal, topicId) {
  ajax(`/discourse-ai/ai-bot/shared-ai-conversations/preview/${topicId}.json`)
    .then((payload) => {
      modal.show(ShareFullTopicModal, { model: payload });
    })
    .catch(popupAjaxError);
}
