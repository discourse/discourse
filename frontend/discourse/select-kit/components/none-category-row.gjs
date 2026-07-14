import { computed } from "@ember/object";
import { trustHTML } from "@ember/template";
import { classNames } from "@ember-decorators/component";
import CategoryRowComponent from "discourse/select-kit/components/category-row";
import { categoryBadgeHTML } from "discourse/ui-kit/helpers/d-category-link";
import dDirSpan from "discourse/ui-kit/helpers/d-dir-span";

@classNames("none category-row")
export default class NoneCategoryRow extends CategoryRowComponent {
  @computed("category")
  get badgeForCategory() {
    return trustHTML(
      categoryBadgeHTML(this.category, {
        link: false,
        allowUncategorized: true,
        hideParent: true,
        ancestors: this.category?.predecessors,
      })
    );
  }

  <template>
    {{#if this.category}}
      <div class="category-status" aria-hidden="true">
        {{this.badgeForCategory}}
      </div>

      {{#if this.shouldDisplayDescription}}
        <div class="category-desc" aria-hidden="true">{{dDirSpan
            this.descriptionText
            htmlSafe="true"
          }}</div>
      {{/if}}
    {{else}}
      {{trustHTML this.label}}
    {{/if}}
  </template>
}
