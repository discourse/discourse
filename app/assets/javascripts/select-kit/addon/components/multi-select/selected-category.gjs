import { on } from "@ember/modifier";
import { computed } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { classNames } from "@ember-decorators/component";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import icon from "discourse/helpers/d-icon";
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

  <template>
    <div
      {{on "click" this.onSelectedNameClick}}
      tabindex="0"
      title={{this.title}}
      data-value={{this.value}}
      data-name={{this.name}}
      class="select-kit-selected-name selected-name choice"
    >
      <div class="body">
        {{this.badge}}
        {{icon "xmark"}}
      </div>
    </div>
  </template>
}
