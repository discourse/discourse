import categoryLink from "discourse/helpers/category-link";
import { iconHTML } from "discourse/lib/icon-library";
import { escapeExpression } from "discourse/lib/utilities";

export function renderCategoryContent(option) {
  const link = categoryLink(option.model, {
    allowUncategorized: true,
    link: false,
  });
  return link;
}

export function renderTagContent(option) {
  return `${iconHTML("tag")}${escapeExpression(option.name)} x ${escapeExpression(option.count)}`;
}

export function renderOptionContent(option) {
  return option.model
    ? renderCategoryContent(option)
    : renderTagContent(option);
}

/**
 * Component-friendly category/tag autocomplete
 * Only returns the content, structure is handled by component
 */
export default function categoryTagAutocompleteComponentTemplate({ options }) {
  return options.map((option, index) => ({
    content: renderOptionContent(option),
    title: option.model ? option.model.name : option.name,
    cssClasses: "",
    item: option,
    index,
  }));
}
