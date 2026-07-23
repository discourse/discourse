export function buildGifPickHandler({ api, draft, isThread, currentUser }) {
  const draftHolder = isThread ? draft.thread : draft.channel;

  return async (message) => {
    try {
      await api.sendChatMessage(draft.channel.id, {
        message,
        threadId: isThread ? draft.thread?.id : null,
        inReplyToId: !isThread ? draft.inReplyTo?.id : null,
      });
    } catch {
      return;
    }
    draftHolder?.resetDraft?.(currentUser);
  };
}

export function buildChatPickerSelectHandler({ api, composer, currentUser }) {
  return (value, tab) => {
    if (tab.id === "emoji") {
      composer.onSelectEmoji(value);
      return;
    }

    buildGifPickHandler({
      api,
      draft: composer.draft,
      isThread: composer.context === "thread",
      currentUser,
    })(value);
  };
}
