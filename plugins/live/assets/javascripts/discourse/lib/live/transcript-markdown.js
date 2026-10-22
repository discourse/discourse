import { serializeBBCodeAttr } from "discourse/lib/text";
import { i18n } from "discourse-i18n";

// chat presents this type as registered by the live-transcript-source initializer
export const TRANSCRIPT_SOURCE_TYPE = "live";

// Renders a recorded transcript as post markdown. When chat is enabled the
// entries reuse chat's transcript markup — one chained [chat] block per
// utterance, which cooks into the familiar quoted-conversation look — with
// the utterance id standing in for the message id and no channel attributes,
// so nothing links anywhere. The first entry names the room as the
// transcript's source, which heads it in place of a channel. Without chat the
// markup wouldn't cook, so plain bbcode quotes are used instead.
export function transcriptToMarkdown(
  entries,
  { chatMarkup = true, roomName } = {}
) {
  return entries
    .map((entry, index) => {
      const username =
        entry.username || i18n("live.transcript.unknown_speaker");
      if (chatMarkup) {
        const timestamp = new Date(entry.startedAt).toISOString();
        const source =
          index === 0 && roomName
            ? `${serializeBBCodeAttr(roomName, "source")}${serializeBBCodeAttr(TRANSCRIPT_SOURCE_TYPE, "sourceType")}`
            : "";
        return `[chat quote="${username};${entry.utteranceId};${timestamp}"${source} chained="true"]\n${entry.text}\n[/chat]`;
      }
      return `[quote="${username}"]\n${entry.text}\n[/quote]`;
    })
    .join("\n\n");
}
