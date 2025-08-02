import { censor } from "pretty-text/censored-words";
import { emojiUnescape } from "discourse/lib/text";
import Site from "discourse/models/site";

export function fancyTitle(topicTitle, supportMixedTextDirection) {
  let title = censor(
    emojiUnescape(topicTitle) || "",
    Site.currentProp("censored_regexp")
  );

  if (supportMixedTextDirection) {
    return `<span dir="auto">${title}</span>`;
  }

  return title;
}
