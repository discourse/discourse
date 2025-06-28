import avatar from "discourse/helpers/avatar";
import { escapeExpression, formatUsername } from "discourse/lib/utilities";
import { iconHTML } from "../icon-library";

/**
 * Component-friendly user autocomplete template
 * Returns only the inner content for each item (without <li><a> wrappers)
 * The component will handle the structure and event binding
 */

export function renderUserItemContent(item) {
  return `
    ${avatar(item, { imageSize: "tiny" })}
    <span class='username'>${escapeExpression(formatUsername(item.username))}</span>
    ${item.name ? `<span class='name'>${escapeExpression(item.name)}</span>` : ""}
    ${item.status ? `<span class='user-status'></span>` : ""}
  `;
}

export function renderEmailItemContent(item) {
  return `
    ${iconHTML("envelope")}
    <span class='username'>${escapeExpression(formatUsername(item.username))}</span>
  `;
}

export function renderGroupItemContent(item) {
  return `
    ${iconHTML("users")}
    <span class='username'>${escapeExpression(item.name)}</span>
    <span class='name'>${escapeExpression(item.full_name)}</span>
  `;
}

export function renderUserItemContentOnly(item) {
  if (item.isUser) {
    return renderUserItemContent(item);
  } else if (item.isEmail) {
    return renderEmailItemContent(item);
  } else if (item.isGroup) {
    return renderGroupItemContent(item);
  } else {
    return "";
  }
}

/**
 * Component-friendly user autocomplete
 * Only returns the CSS classes and content, structure is handled by component
 */
export default function userAutocompleteComponentTemplate({ options }) {
  return options.map((item, index) => ({
    content: renderUserItemContentOnly(item),
    title: item.name
      ? escapeExpression(item.name)
      : item.full_name
        ? escapeExpression(item.full_name)
        : escapeExpression(item.username),
    cssClasses: item.cssClasses || "",
    item,
    index,
  }));
}
