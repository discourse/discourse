import { isHTMLSafe, type SafeString, trustHTML } from "@ember/template";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";

/**
 * Replaces emoji codes in a text with emoji images.
 *
 * @param text - The text. Plain text is escaped; trusted HTML is kept as is.
 * @param options - Options for `emojiUnescape`, such as a `title`.
 * @returns The text with emoji images.
 */
export default function dReplaceEmoji(
  text: string | SafeString | null | undefined,
  options?: Record<string, unknown> | null
) {
  text = isHTMLSafe(text) ? text.toString() : escapeExpression(text);
  // `trustHTML` treats the `undefined` an empty text unescapes to like `""`.
  return trustHTML(emojiUnescape(text, options) as string);
}
