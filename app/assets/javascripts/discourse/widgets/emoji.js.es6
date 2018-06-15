import { createWidget } from "discourse/widgets/widget";
import { emojiUrlFor, emojiUnescape } from "discourse/lib/text";
import RawHtml from "discourse/widgets/raw-html";

export function replaceEmoji(str) {
  const escaped = emojiUnescape(Handlebars.Utils.escapeExpression(str));
  return [new RawHtml({ html: `<span>${escaped}</span>` })];
}

export default createWidget("emoji", {
  tagName: "img.emoji",

  buildAttributes(attrs) {
    let result = { src: emojiUrlFor(attrs.name), alt: `:${attrs.name}:` };
    if (attrs.title) result.title = attrs.name;
    return result;
  }
});
