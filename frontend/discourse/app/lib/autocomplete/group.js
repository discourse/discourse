import { escapeExpression } from "discourse/lib/utilities";

function renderOption(option) {
  return `<li><a href><span class='text-content'>${escapeExpression(option.name)}</span></a></li>`;
}

export default function groupAutocomplete({ options }) {
  return `
  <div class='autocomplete ac-group'>
    <ul>
      ${options.map(renderOption).join("")}
    </ul>
  </div>
`;
}
