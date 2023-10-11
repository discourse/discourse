import { htmlSafe } from "@ember/template";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("emoji", function (code, options) {
  return emoji(code, options);
});

export default function emoji(code, options) {
  const escaped = escapeExpression(`:${code}:`);
  return htmlSafe(emojiUnescape(escaped, options));
}
