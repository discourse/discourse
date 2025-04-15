import { htmlSafe } from "@ember/template";
import { classNames } from "@ember-decorators/component";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import dirSpan from "discourse/helpers/dir-span";
import discourseComputed from "discourse/lib/decorators";
import CategoryRowComponent from "select-kit/components/category-row";

@classNames("none category-row")
export default class NoneCategoryRow extends CategoryRowComponent {
  @discourseComputed("category")
  badgeForCategory(category) {
    return htmlSafe(
      categoryBadgeHTML(category, {
        link: false,
        allowUncategorized: true,
        hideParent: true,
      })
    );
  }

  <template>
    {{#if this.category}}
      <div class="category-status" aria-hidden="true">
        {{#if this.hasParentCategory}}
          {{#unless this.hideParentCategory}}
            {{this.badgeForParentCategory}}
          {{/unless}}
        {{/if}}
        {{this.badgeForCategory}}
      </div>

      {{#if this.shouldDisplayDescription}}
        <div class="category-desc" aria-hidden="true">{{dirSpan
            this.descriptionText
            htmlSafe="true"
          }}</div>
      {{/if}}
    {{else}}
      {{htmlSafe this.label}}
    {{/if}}
  </template>
}
