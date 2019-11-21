import Mixin from "@ember/object/mixin";
import { computed } from "@ember/object";
import Category from "discourse/models/category";

export default Mixin.create({
  filterModeInternal: computed(
    "rawFilterMode",
    "filterType",
    "category",
    "noSubcategories",
    function() {
      const rawFilterMode = this.get("rawFilterMode");
      if (rawFilterMode) {
        return rawFilterMode;
      } else {
        const category = this.get("category");
        const filterType = this.get("filterType");

        if (category) {
          const noSubcategories = this.get("noSubcategories");

          return `c/${Category.slugFor(category)}${
            noSubcategories ? "/none" : ""
          }/l/${filterType}`;
        } else {
          return filterType;
        }
      }
    }
  ),

  filterMode: computed("filterModeInternal", {
    get() {
      return this.get("filterModeInternal");
    },

    set(key, value) {
      this.set("rawFilterMode", value);
      const parts = value.split("/");

      if (parts.length >= 2 && parts[parts.length - 2] === "top") {
        this.set("filterType", "top");
      } else {
        this.set("filterType", parts.pop());
      }

      return value;
    }
  })
});
