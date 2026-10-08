import { trustHTML } from "@ember/template";
import { helperContext } from "discourse/lib/helpers";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";

export default function dEmoji(code, options) {
  // With emoji disabled the code would otherwise leak into the UI as literal
  // `:code:` text.
  if (!helperContext().siteSettings.enable_emoji) {
    return;
  }

  const escaped = escapeExpression(`:${code}:`);
  return trustHTML(emojiUnescape(escaped, options));
}
