import { computed } from "@ember/object";
import { trustHTML } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import SelectedChoiceComponent from "discourse/select-kit/components/selected-choice";
import { categoryBadgeHTML } from "discourse/ui-kit/helpers/d-category-link";

@tagName("")
export default class SelectedChoiceCategory extends SelectedChoiceComponent {
  extraClass = "selected-choice-category";

  @computed("item")
  get badge() {
    return trustHTML(
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
