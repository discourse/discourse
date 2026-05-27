import { on } from "@ember/modifier";
import { computed } from "@ember/object";
import { trustHTML } from "@ember/template";
import { classNames } from "@ember-decorators/component";
import SelectedNameComponent from "discourse/select-kit/components/selected-name";
import { categoryBadgeHTML } from "discourse/ui-kit/helpers/d-category-link";
import dIcon from "discourse/ui-kit/helpers/d-icon";

@classNames("selected-category")
export default class SelectedCategory extends SelectedNameComponent {
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
        {{dIcon "xmark"}}
      </div>
    </div>
  </template>
}
