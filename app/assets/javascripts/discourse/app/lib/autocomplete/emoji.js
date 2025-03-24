import { escapeExpression } from "discourse/lib/utilities";

function renderOption({ src, code, label }) {
  const content = src
    ? `<img src="${escapeExpression(src)}" class="emoji">` +
      `<span class='emoji-shortname'>${escapeExpression(code)}</span>`
    : escapeExpression(label);

  return `<li><a href>${content}</a></li>`;
}

export default function renderEmojiAutocomplete({ options }) {
  return `
    <div class='autocomplete ac-emoji'>
      <ul>
        ${options.map(renderOption).join("")}
      </ul>
    </div>
  `;
}
