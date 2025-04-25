<<<<<<< HEAD
<SelectedChoice
  @item={{this.item}}
  @selectKit={{this.selectKit}}
  @extraClass={{this.extraClass}}
>
  {{this.badge}}
</SelectedChoice>
=======
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
<<<<<<< HEAD
}
>>>>>>> a9ddbde3f6 (DEV: [gjs-codemod] renamed js to gjs)
=======

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
>>>>>>> e41897a306 (DEV: [gjs-codemod] Convert final core components/routes to gjs)
