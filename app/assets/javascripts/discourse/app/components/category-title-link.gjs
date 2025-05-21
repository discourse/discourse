import Component from "@glimmer/component";
import { or } from "truth-helpers";
import CategoryLogo from "discourse/components/category-logo";
import CategoryTitleBefore from "discourse/components/category-title-before";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import dirSpan from "discourse/helpers/dir-span";
import element from "discourse/helpers/element";

export default class CategoryTitleLink extends Component {
  get displayName() {
    if (this.args.unstyled === true) {
      return dirSpan(this.args.category.displayName);
    }

    const categoryBadge = categoryBadgeHTML(this.args.category, {
      allowUncategorized: true,
      link: false,
    });

    return dirSpan(categoryBadge, { htmlSafe: "true" });
  }

  <template>
    {{#let (element (or @tagName "h3")) as |TagName|}}
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
