import Component from "@glimmer/component";
import CategoryLogo from "discourse/components/category-logo";
import CategoryTitleBefore from "discourse/components/category-title-before";
import { or } from "discourse/truth-helpers";
import { categoryBadgeHTML } from "discourse/ui-kit/helpers/d-category-link";
import dDirSpan from "discourse/ui-kit/helpers/d-dir-span";
import dElement from "discourse/ui-kit/helpers/d-element";

export default class CategoryTitleLink extends Component {
  get displayName() {
    if (this.args.unstyled === true) {
      return dDirSpan(this.args.category.displayName);
    }

    const categoryBadge = categoryBadgeHTML(this.args.category, {
      allowUncategorized: true,
      link: false,
    });

    return dDirSpan(categoryBadge, { htmlSafe: "true" });
  }

  <template>
    {{#let (dElement (or @tagName "h3")) as |TagName|}}
      <TagName>
        <a class="category-title-link" href={{@category.url}}>
          <div class="category-text-title">
            <CategoryTitleBefore @category={{@category}} />
            <span class="category-name">{{this.displayName}}</span>
          </div>
          {{#if @category.uploaded_logo.url}}
            <CategoryLogo @category={{@category}} />
          {{/if}}
        </a>
      </TagName>
    {{/let}}
  </template>
}

// icon name defined on prototype so it can be easily overridden in theme components
CategoryTitleLink.prototype.lockIcon = "lock";
