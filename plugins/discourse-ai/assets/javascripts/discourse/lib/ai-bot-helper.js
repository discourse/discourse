import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import ShareFullTopicModal from "../components/modal/share-full-topic-modal";

const MAX_AGENT_USER_ID = -1200;

let enabledAgentMap = null;

function ensureAgentMap() {
  if (!enabledAgentMap) {
    const currentUser = getOwnerWithFallback(this).lookup(
      "service:current-user"
    );
    enabledAgentMap = {};
    currentUser?.ai_enabled_agents?.forEach((agent) => {
      enabledAgentMap[agent.user_id] = agent;
    });
  }
}

export function isGPTBot(user) {
  if (!user) {
    return;
  }

  ensureAgentMap();
  return !!enabledAgentMap[user.id];
}

export function getBotType(user) {
  return isGPTBot(user) ? "agent" : undefined;
}

export function isPostFromAiBot(post, currentUser) {
  return (
    !!post.llm_name ||
    post.user_id <= MAX_AGENT_USER_ID ||
    !!currentUser?.ai_enabled_agents?.some(
      (agent) => post.username === agent.username
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

export function isAiBotRecipient(recipients, currentUser) {
  if (!recipients) {
    return false;
  }

  const usernames = recipients
    .split(",")
    .map((username) => username.trim().toLowerCase());

  return !!currentUser?.ai_enabled_agents?.some((agent) =>
    usernames.includes(agent.username.toLowerCase())
  );
}
