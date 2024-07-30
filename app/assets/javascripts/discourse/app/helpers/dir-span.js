import { htmlSafe } from "@ember/template";
import { escapeExpression } from "discourse/lib/utilities";
import { helperContext, registerRawHelper } from "discourse-common/lib/helpers";

function setDir(text) {
  let content = text ? text : "";
  let siteSettings = helperContext().siteSettings;
  const mixed = siteSettings.support_mixed_text_direction;
  return `<span ${mixed ? 'dir="auto"' : ""}>${content}</span>`;
}

registerRawHelper("dir-span", dirSpan);

export default function dirSpan(str, params = {}) {
  let isHtmlSafe = false;
  if (params.htmlSafe) {
    isHtmlSafe = params.htmlSafe === "true";
  }
  let text = isHtmlSafe ? str : escapeExpression(str);
  return htmlSafe(setDir(text));
}
