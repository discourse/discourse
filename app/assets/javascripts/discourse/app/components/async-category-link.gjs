import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import categoryLink from "discourse/helpers/category-link";
import Category from "discourse/models/category";

export default class AsyncCategoryLink extends Component {
  @tracked category;

  constructor() {
    super(...arguments);
    this.request = Promise.resolve();
    this.categoryChanged();
  }

  async triggerCategoryChange(previousRequest) {
    const category = await Category.asyncFindById(this.args.categoryId);
    await previousRequest;
    this.category = category;
  }

  categoryChanged() {
    this.request = this.triggerCategoryChange(this.request);
  }

  <template>
    <div {{didUpdate this.categoryChanged @categoryId}}>
      {{#if this.category}}
        {{categoryLink this.category}}
      {{/if}}
    </div>
  </template>
}
