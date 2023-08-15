import Category from "discourse/models/category";

export function calculateFilterMode({ category, filterType, noSubcategories }) {
  if (category) {
    return `c/${Category.slugFor(category)}${
      noSubcategories ? "/none" : ""
    }/l/${filterType}`;
  } else {
    return filterType;
  }
}

export function filterTypeForMode(mode) {
  return mode.split("/").pop();
}
