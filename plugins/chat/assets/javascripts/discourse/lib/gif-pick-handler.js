// Builds the customPickHandler passed to GifsModal from the chat composer's
// GIF button. Extracted so the send + draft-reset interplay can be unit tested.
//
// The returned handler:
//   - Sends the picked GIF as a chat message in the active context (channel or
//     thread, with inReplyTo when replying in a channel).
//   - On a successful send, resets the *correct* draft (thread when in a
//     thread context, channel otherwise) for the given user.
//   - On send failure, leaves the draft intact so the user can retry.
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
