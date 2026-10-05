const DRAFT_KEY = "ai-bot-conversations-draft";

export function storeConversationDraft(sessionStore, text) {
  if (text?.trim()) {
    sessionStore.set({ key: DRAFT_KEY, value: text });
  } else {
    sessionStore.remove(DRAFT_KEY);
  }
}

export function takeConversationDraft(sessionStore) {
  const draft = sessionStore.get(DRAFT_KEY);
  sessionStore.remove(DRAFT_KEY);
  return draft;
}
