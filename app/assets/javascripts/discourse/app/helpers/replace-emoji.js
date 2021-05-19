import { emojiUnescape } from "discourse/lib/text";
import { htmlSafe } from "@ember/template";
import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("replace-emoji", (text, options) => {
  return htmlSafe(emojiUnescape(text, options));
});
