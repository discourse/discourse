import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import CategoryLogo from "discourse/components/category-logo";
import CategoryTitleBefore from "discourse/components/category-title-before";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import dirSpan from "discourse/helpers/dir-span";

@tagName("h3")
export default class CategoryTitleLink extends Component {
  get displayName() {
    if (this.unstyled === true) {
      return dirSpan(this.category.displayName);
    }

    const categoryBadge = categoryBadgeHTML(this.category, {
      allowUncategorized: true,
      link: false,
    });

    return dirSpan(categoryBadge, { htmlSafe: "true" });
  }

  <template>
    <a class="category-title-link" href={{this.category.url}}>
      <div class="category-text-title">
        <CategoryTitleBefore @category={{this.category}} />
        <span class="category-name">{{this.displayName}}</span>
      </div>
      {{#if this.category.uploaded_logo.url}}
        <CategoryLogo @category={{this.category}} />
      {{/if}}
    </a>
  </template>
}

// icon name defined on prototype so it can be easily overridden in theme components
CategoryTitleLink.prototype.lockIcon = "lock";
