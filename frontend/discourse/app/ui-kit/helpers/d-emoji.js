import { trustHTML } from "@ember/template";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";

export default function dEmoji(code, options) {
  const escaped = escapeExpression(`:${code}:`);
  return trustHTML(emojiUnescape(escaped, options));
}
