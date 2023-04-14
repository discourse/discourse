import Category from "discourse/models/category";
import { computed, get } from "@ember/object";

export default function categoryFromId(property) {
  return computed(property, function () {
    return Category.findById(get(this, property));
  });
}
