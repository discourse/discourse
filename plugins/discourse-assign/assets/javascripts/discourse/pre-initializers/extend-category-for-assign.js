import { computed } from "@ember/object";
import Category from "discourse/models/category";

export default {
  name: "extend-category-for-assign",
  before: "inject-discourse-objects",

  initialize() {
    Category.reopen({
      enable_unassigned_filter: computed(
        "custom_fields.enable_unassigned_filter",
        {
          get() {
            return this?.custom_fields?.enable_unassigned_filter === "true";
          },
        }
      ),
    });
  },
};
