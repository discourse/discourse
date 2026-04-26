import { isHTMLSafe, trustHTML } from "@ember/template";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";

export default function replaceEmoji(text, options) {
  text = isHTMLSafe(text) ? text.toString() : escapeExpression(text);
  return trustHTML(emojiUnescape(text, options));
}
