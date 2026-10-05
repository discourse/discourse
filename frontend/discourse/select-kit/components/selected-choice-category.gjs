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
    const options = { allowUncategorized: true, link: false };

    if (this.selectKit.options.showAncestorsInSelectedChoice) {
      options.ancestors = this.item.predecessors;
      options.hideParent = true;
    }

    return trustHTML(categoryBadgeHTML(this.item, options));
  }

  <template>
    <SelectedChoiceComponent
      @extraClass={{this.extraClass}}
      @item={{this.item}}
      @selectKit={{this.selectKit}}
    >
      {{this.badge}}
    </SelectedChoiceComponent>
  </template>
}
