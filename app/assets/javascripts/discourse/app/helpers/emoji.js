import { htmlSafe } from "@ember/template";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { registerRawHelper } from "discourse-common/lib/helpers";

registerRawHelper("emoji", emoji);
export default function emoji(code, options) {
  const escaped = escapeExpression(`:${code}:`);
  return htmlSafe(emojiUnescape(escaped, options));
}
