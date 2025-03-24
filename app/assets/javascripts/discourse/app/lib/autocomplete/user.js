import avatar from "discourse/helpers/avatar";
import { escapeExpression, formatUsername } from "discourse/lib/utilities";
import { iconHTML } from "../icon-library";

function renderUserItem(item) {
  return `
    <li data-index="${escapeExpression(item.index?.toString())}">
      <a href title="${escapeExpression(item.name)}" class="${escapeExpression(item.cssClasses)}">
        ${avatar(item, { imageSize: "tiny" })}
        <span class='username'>${escapeExpression(formatUsername(item.username))}</span>
        ${item.name ? `<span class='name'>${escapeExpression(item.name)}</span>` : ""}
        ${item.status ? `<span class='user-status'></span>` : ""}
      </a>
    </li>
  `;
}

function renderEmailItem(item) {
  return `
    <li>
      <a href title="${escapeExpression(item.username)}">
        ${iconHTML("envelope")}
        <span class='username'>${escapeExpression(formatUsername(item.username))}</span>
      </a>
    </li>
  `;
}

function renderGroupItem(item) {
  return `
    <li>
      <a href title="${escapeExpression(item.full_name)}">
        ${iconHTML("users")}
        <span class='username'>${escapeExpression(item.name)}</span>
        <span class='name'>${escapeExpression(item.full_name)}</span>
      </a>
    </li>
  `;
}

function renderItem(item) {
  if (item.isUser) {
    return renderUserItem(item);
  } else if (item.isEmail) {
    return renderEmailItem(item);
  } else if (item.isGroup) {
    return renderGroupItem(item);
  } else {
    return "";
  }
}

export default function userAutocomplete({ options }) {
  return `
    <div class='autocomplete ac-user'>
      <ul>
        ${options.map(renderItem).join("")}
      </ul>
    </div>
  `;
}
