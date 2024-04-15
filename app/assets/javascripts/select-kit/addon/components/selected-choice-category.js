import { computed } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import SelectedChoiceComponent from "select-kit/components/selected-choice";

export default SelectedChoiceComponent.extend({
  tagName: "",
  extraClass: "selected-choice-category",

  badge: computed("item", function () {
    return htmlSafe(
      categoryBadgeHTML(this.item, {
        allowUncategorized: true,
        link: false,
      })
    );
  }),
});
