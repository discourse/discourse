import { computed, get } from "@ember/object";
import Category from "discourse/models/category";

export default function categoryFromId(property) {
  return computed(property, function () {
    return Category.findById(get(this, property));
  });
}
