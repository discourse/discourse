import { htmlSafe, isHTMLSafe } from "@ember/template";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { registerRawHelper } from "discourse-common/lib/helpers";

registerRawHelper("replace-emoji", replaceEmoji);

export default function replaceEmoji(text, options) {
  text = isHTMLSafe(text) ? text.toString() : escapeExpression(text);
  return htmlSafe(emojiUnescape(text, options));
}
