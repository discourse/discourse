import { i18n } from "discourse-i18n";

export function limitText(text, limit) {
  const prefix = text.slice(0, limit);
  // The input length limit counts UTF-16 code units. Keep the last character whole.
  return prefix.isWellFormed() ? prefix : prefix.slice(0, -1);
}

export function itemLabel(item) {
  if (item.type !== "display_text") {
    return item.label || i18n("form_definition.untitled");
  }
  const text = item.content?.trim().replace(/\s+/gu, " ");
  if (!text) {
    return i18n("form_definition.types.display_text");
  }
  return i18n("form_definition.display_text_excerpt", {
    excerpt: text.length > 50 ? limitText(text, 49) + "…" : text,
  });
}
