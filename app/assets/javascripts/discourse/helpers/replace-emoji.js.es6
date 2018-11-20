import { registerUnbound } from "discourse-common/lib/helpers";
import { emojiUnescape } from "discourse/lib/text";

registerUnbound(
  "replace-emoji",
  text => new Handlebars.SafeString(emojiUnescape(text))
);
