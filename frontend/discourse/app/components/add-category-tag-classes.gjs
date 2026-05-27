import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import bodyClass from "discourse/helpers/body-class";

export default class AddCategoryTagClasses extends Component {
  get tagNames() {
    return this.args.tags?.map((tag) => tag.name ?? tag);
  }

  <template>
    {{#if @category}}
      {{bodyClass "category" (concat "category-" @category.fullSlug)}}
    {{/if}}

    {{#each this.tagNames as |tagName|}}
      {{bodyClass (concat "tag-" tagName)}}
    {{/each}}
  </template>
}
