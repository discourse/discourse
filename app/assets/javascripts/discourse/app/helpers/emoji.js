import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { htmlSafe } from "@ember/template";
import { helper } from "@ember/component/helper";

function emoji(code, options) {
  const escaped = escapeExpression(`:${code}:`);
  return htmlSafe(emojiUnescape(escaped, options));
}

export default helper(emoji);
