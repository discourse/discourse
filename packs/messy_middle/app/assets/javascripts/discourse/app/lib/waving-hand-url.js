import { helperContext } from "discourse-common/lib/helpers";
import { emojiBasePath } from "discourse/lib/settings";
import getURL from "discourse-common/lib/get-url";

export function wavingHandURL() {
  const emojiSet = helperContext().siteSettings.emoji_set;

  // random number between 2 -6 to render multiple skin tone waving hands
  const random = Math.floor(Math.random() * (7 - 2) + 2);
  return getURL(`${emojiBasePath()}/${emojiSet}/wave/${random}.png`);
}
