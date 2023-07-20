import { emojiUnescape } from "discourse/lib/text";
import { htmlSafe, isHTMLSafe } from "@ember/template";
import { registerUnbound } from "discourse-common/lib/helpers";
import { escapeExpression } from "discourse/lib/utilities";

registerUnbound("replace-emoji", (text, options) => {
  text = isHTMLSafe(text) ? text.toString() : escapeExpression(text);
  return htmlSafe(emojiUnescape(text, options));
});
