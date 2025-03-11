import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import CategoryLogo from "discourse/components/category-logo";
import CategoryTitleBefore from "discourse/components/category-title-before";
import icon from "discourse/helpers/d-icon";
import dirSpan from "discourse/helpers/dir-span";

@tagName("h3")
export default class CategoryTitleLink extends Component {
  <template>
    <a class="category-title-link" href={{this.category.url}}>
      <div class="category-text-title">
        <CategoryTitleBefore @category={{this.category}} />
        {{#if this.category.read_restricted}}
          {{icon this.lockIcon}}
        {{/if}}
        <span class="category-name">{{dirSpan this.category.displayName}}</span>
      </div>
      {{#if this.category.uploaded_logo.url}}
        <CategoryLogo @category={{this.category}} />
      {{/if}}
    </a>
  </template>
}

// icon name defined on prototype so it can be easily overridden in theme components
CategoryTitleLink.prototype.lockIcon = "lock";
