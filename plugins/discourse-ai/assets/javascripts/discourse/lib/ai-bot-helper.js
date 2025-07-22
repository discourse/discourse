import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import Composer from "discourse/models/composer";
import { i18n } from "discourse-i18n";
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
    !!currentUser?.ai_enabled_chat_bots?.any(
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

export async function composeAiBotMessage(
  targetBot,
  composer,
  options = {
    skipFocus: false,
    topicBody: "",
    personaUsername: null,
  }
) {
  const currentUser = composer.currentUser;
  const draftKey = "new_private_message_ai_" + new Date().getTime();

  let botUsername;
  if (targetBot) {
    botUsername = currentUser.ai_enabled_chat_bots.find(
      (bot) => bot.model_name === targetBot
    )?.username;
  } else if (options.personaUsername) {
    botUsername = options.personaUsername;
  } else {
    botUsername = currentUser.ai_enabled_chat_bots[0].username;
  }

  const data = {
    action: Composer.PRIVATE_MESSAGE,
    recipients: botUsername,
    topicTitle: i18n("discourse_ai.ai_bot.default_pm_prefix"),
    archetypeId: "private_message",
    draftKey,
    hasGroups: false,
    warningsDisabled: true,
  };

  if (options.skipFocus) {
    data.topicBody = options.topicBody;
    await composer.open(data);
  } else {
    composer.focusComposer({ fallbackToNewTopic: true, openOpts: data });
  }
}
