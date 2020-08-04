import { get } from "@ember/object";
import Helper from "@ember/component/helper";

export function formatCurrency([reviewable, fieldId]) {
  // The field `category_id` corresponds to `category`
  if (fieldId === "category_id") {
    fieldId = "category.id";
  }

  let value = get(reviewable, fieldId);

  // If it's an array, say tags, make a copy so we aren't mutating the original
  if (Array.isArray(value)) {
    value = value.slice(0);
  }

  return value;
}

export default Helper.helper(formatCurrency);
