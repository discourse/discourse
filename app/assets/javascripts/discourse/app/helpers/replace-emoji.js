import { htmlSafe, isHTMLSafe } from "@ember/template";
import { registerRawHelper } from "discourse/lib/helpers";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";

registerRawHelper("replace-emoji", replaceEmoji);

export default function replaceEmoji(text, options) {
  text = isHTMLSafe(text) ? text.toString() : escapeExpression(text);
  return htmlSafe(emojiUnescape(text, options));
}
