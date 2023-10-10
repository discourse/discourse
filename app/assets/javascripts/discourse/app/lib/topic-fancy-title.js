import { censor } from "pretty-text/censored-words";
import { emojiUnescape } from "discourse/lib/text";
import { isRTL } from "discourse/lib/text-direction";
import Site from "discourse/models/site";

export function fancyTitle(topicTitle, supportMixedTextDirection) {
  let title = censor(
    emojiUnescape(topicTitle) || "",
    Site.currentProp("censored_regexp")
  );

  if (supportMixedTextDirection) {
    const titleDir = isRTL(title) ? "rtl" : "ltr";
    return `<span dir="${titleDir}">${title}</span>`;
  }

  return title;
}
