import { emojiUnescape, emojiUrlFor } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import RawHtml from "discourse/widgets/raw-html";
import { createWidget } from "discourse/widgets/widget";

export function replaceEmoji(str) {
  const escaped = emojiUnescape(escapeExpression(str));
  return [new RawHtml({ html: `<span>${escaped}</span>` })];
}

export default createWidget("emoji", {
  tagName: "img.emoji",

  buildAttributes(attrs) {
    let result = {
      src: emojiUrlFor(attrs.name),
      alt: `:${attrs.alt || attrs.name}:`,
    };
    if (attrs.title) {
      result.title = typeof attrs.title === "string" ? attrs.title : attrs.name;
    }
    return result;
  },
});
