import getURL from "discourse/lib/get-url";
import { helperContext } from "discourse/lib/helpers";
import { emojiBasePath } from "discourse/lib/settings";

export function wavingHandURL() {
  const emojiSet = helperContext().siteSettings.emoji_set;

  // random number between 2 -6 to render multiple skin tone waving hands
  const random = Math.floor(Math.random() * (7 - 2) + 2);
  return getURL(`${emojiBasePath()}/${emojiSet}/wave/${random}.png`);
}
