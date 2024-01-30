import { computed } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import SelectedNameComponent from "select-kit/components/selected-name";

export default SelectedNameComponent.extend({
  classNames: ["selected-category"],

  badge: computed("item", function () {
    return htmlSafe(
      categoryBadgeHTML(this.item, {
        allowUncategorized: true,
        link: false,
      })
    );
  }),
});
