import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  ALL_CATEGORIES_ID,
  NO_CATEGORIES_ID,
} from "select-kit/components/category-drop";

export default class CategoryDropMoreCollection extends Component {
  @service site;

  tagName = "";

  get moreCount() {
    if (!this.args.selectKit.totalCount) {
      return 0;
    }

    const currentCount = this.args.collection.content.filter(
      (category) =>
        category.id !== NO_CATEGORIES_ID && category.id !== ALL_CATEGORIES_ID
    ).length;

    return this.args.selectKit.totalCount - currentCount;
  }

  get slugPath() {
    return this.args.selectKit.options.parentCategory.path.substring(
      "/c/".length
    );
  }

  <template>
    {{#if this.moreCount}}
      <div class="category-drop-footer">
        <span>
          {{i18n "categories.plus_more_count" (hash count=this.moreCount)}}
        </span>

        {{#if @selectKit.options.parentCategory}}
          <LinkTo @route="discovery.subcategories" @model={{this.slugPath}}>
            {{i18n "categories.view_all"}}
            {{icon "up-right-from-square"}}
          </LinkTo>
        {{else}}
          <LinkTo @route="discovery.categories">
            {{i18n "categories.view_all"}}
            {{icon "up-right-from-square"}}
          </LinkTo>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
