import { computed } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { classNames } from "@ember-decorators/component";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import SelectedNameComponent from "select-kit/components/selected-name";

@classNames("selected-category")
export default class SelectedCategory extends SelectedNameComponent {
  @computed("item")
  get badge() {
    return htmlSafe(
      categoryBadgeHTML(this.item, {
        allowUncategorized: true,
        link: false,
      })
    );
  }
}
