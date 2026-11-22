import { aiBadgeAttributes } from "discourse-markdown-it/ai-badge";

export function createAiBadge() {
  const badge = document.createElement("span");
  for (const [name, value] of Object.entries(aiBadgeAttributes())) {
    badge.setAttribute(name, value);
  }
  badge.contentEditable = false;
  return badge;
}
