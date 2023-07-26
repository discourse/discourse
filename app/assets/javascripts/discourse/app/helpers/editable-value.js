import { get } from "@ember/object";

export default function editableValue(reviewable, fieldId) {
  // The field `category_id` corresponds to `category`
  if (fieldId === "category_id") {
    fieldId = "category.id";
  }

  const value = get(reviewable, fieldId);

  // If it's an array, say tags, make a copy so we aren't mutating the original
  if (Array.isArray(value)) {
    return value.slice(0);
  }

  return value;
}
