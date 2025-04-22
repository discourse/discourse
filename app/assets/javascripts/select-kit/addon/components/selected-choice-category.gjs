import { computed } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import SelectedChoiceComponent from "select-kit/components/selected-choice";

@tagName("")
export default class SelectedChoiceCategory extends SelectedChoiceComponent {
  extraClass = "selected-choice-category";

  @computed("item")
  get badge() {
    return htmlSafe(
      categoryBadgeHTML(this.item, {
        allowUncategorized: true,
        link: false,
      })
    );
  }

  <template>
    <SelectedChoiceComponent
      @item={{this.item}}
      @selectKit={{this.selectKit}}
      @extraClass={{this.extraClass}}
    >
      {{this.badge}}
    </SelectedChoiceComponent>
  </template>
}
