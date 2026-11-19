import { i18n } from "discourse-i18n";

export function aiBadgeAttributes() {
  return {
    class: "ai-badge",
    "data-ai-label": i18n("post.ai_generated"),
    title: i18n("post.ai_generated_title"),
  };
}

export function renderAiBadge(md) {
  const attributes = Object.entries(aiBadgeAttributes())
    .map(([name, value]) => `${name}="${md.utils.escapeHtml(value)}"`)
    .join(" ");

  return `<span ${attributes}></span>`;
}

export const aiBadgeAllowList = [
  "span.ai-badge",
  "span[data-ai-label]",
  "span[title]",
];
