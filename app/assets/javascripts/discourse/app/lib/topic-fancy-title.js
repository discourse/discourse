import Site from "discourse/models/site";
import { censor } from "pretty-text/censored-words";
import { emojiUnescape } from "discourse/lib/text";
import { isRTL } from "discourse/lib/text-direction";

export function fancyTitle(title, supportMixedTextDirection) {
  let fancyTitle = censor(
    emojiUnescape(title) || "",
    Site.currentProp("censored_regexp")
  );

  if (supportMixedTextDirection) {
    const titleDir = isRTL(title) ? "rtl" : "ltr";
    return `<span dir="${titleDir}">${fancyTitle}</span>`;
  }

  return fancyTitle;
}
