import categoryLink from "discourse/helpers/category-link";
import { iconHTML } from "discourse/lib/icon-library";
import { escapeExpression } from "discourse/lib/utilities";

export function renderCategory(option) {
  const link = categoryLink(option.model, {
    allowUncategorized: true,
    link: false,
  });

  return `<li><a href>${link}</a></li>`;
}

export function renderTag(option) {
  const text = `${escapeExpression(option.name)} x ${escapeExpression(option.count)}`;
  return `<li><a href>${iconHTML("tag")}${text}</a></li>`;
}

export function renderOption(option) {
  return option.model ? renderCategory(option) : renderTag(option);
}

export default function categoryTagAutocomplete({ options }) {
  return `
    <div class='autocomplete ac-category-or-tag'>
      <ul>
        ${options.map(renderOption).join("")}
      </ul>
    </div>
  `;
}
