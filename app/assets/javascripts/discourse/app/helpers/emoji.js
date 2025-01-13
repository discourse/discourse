import { htmlSafe } from "@ember/template";
import { registerRawHelper } from "discourse/lib/helpers";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";

registerRawHelper("emoji", emoji);
export default function emoji(code, options) {
  const escaped = escapeExpression(`:${code}:`);
  return htmlSafe(emojiUnescape(escaped, options));
}
