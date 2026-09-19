import { i18n } from "discourse-i18n";

// Renders a recorded transcript as post markdown. When chat is enabled the
// entries reuse chat's transcript markup — one chained [chat] block per
// utterance, which cooks into the familiar quoted-conversation look — with
// the utterance id standing in for the message id and no channel attributes,
// so nothing links anywhere. Without chat the markup wouldn't cook, so plain
// bbcode quotes are used instead.
export function transcriptToMarkdown(entries, { chatMarkup = true } = {}) {
  return entries
    .map((entry) => {
      const username =
        entry.username || i18n("voice.transcript.unknown_speaker");
      if (chatMarkup) {
        const timestamp = new Date(entry.startedAt).toISOString();
        return `[chat quote="${username};${entry.utteranceId};${timestamp}" chained="true"]\n${entry.text}\n[/chat]`;
      }
      return `[quote="${username}"]\n${entry.text}\n[/quote]`;
    })
    .join("\n\n");
}
