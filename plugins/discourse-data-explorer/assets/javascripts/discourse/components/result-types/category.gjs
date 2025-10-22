import Component from "@glimmer/component";
import { categoryLinkHTML } from "discourse/helpers/category-link";

export default class Category extends Component {
  get categoryBadgeReplacement() {
    return categoryLinkHTML(this.args.ctx.category, {
      allowUncategorized: true,
    });
  }

  <template>
    {{#if @ctx.category}}
      {{this.categoryBadgeReplacement}}
    {{else}}
      <a href="{{@ctx.baseuri}}/t/{{@ctx.id}}">{{@ctx.id}}</a>
    {{/if}}
  </template>
}
