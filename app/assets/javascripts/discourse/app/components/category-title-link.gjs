import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";

@tagName("h3")
export default class CategoryTitleLink extends Component {}

// icon name defined on prototype so it can be easily overridden in theme components
CategoryTitleLink.prototype.lockIcon = "lock";

<a class="category-title-link" href={{this.category.url}}>
  <div class="category-text-title">
    <CategoryTitleBefore @category={{this.category}} />
    {{#if this.category.read_restricted}}
      {{d-icon this.lockIcon}}
    {{/if}}
    <span class="category-name">{{dir-span this.category.displayName}}</span>
  </div>
  {{#if this.category.uploaded_logo.url}}
    <CategoryLogo @category={{this.category}} />
  {{/if}}
</a>