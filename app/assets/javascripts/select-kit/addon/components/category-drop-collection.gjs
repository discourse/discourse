import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import {
  ALL_CATEGORIES_ID,
  NO_CATEGORIES_ID,
} from "select-kit/components/category-drop";
import { MAIN_COLLECTION } from "select-kit/components/select-kit";

export default class CategoryDropCollection extends Component {
  @service site;

  tagName = "";

  componentForRow(collectionForIdentifier, item, selectKit) {
    return selectKit.modifyComponentForRow(collectionForIdentifier, item);
  }

  get showMoreCount() {
    return (
      // Not all categories are displayed only when lazy_load_categories is enabled
      this.site.lazy_load_categories &&
      this.args.collection.identifier === MAIN_COLLECTION &&
      this.moreCount > 0
    );
  }

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

  <template>
    {{#if @collection.content.length}}
      <ul class="select-kit-collection" aria-live="polite" role="menu">
        {{#each @collection.content as |item index|}}
          {{component
            (this.componentForRow @collection.identifier item @selectKit)
            index=index
            item=item
            value=@value
            selectKit=@selectKit
          }}
        {{/each}}
      </ul>
      {{#if this.showMoreCount}}
        <div class="category-drop-footer">
          <span>{{i18n
              "categories.plus_more_count"
              (hash count=this.moreCount)
            }}</span>
          <LinkTo @route="discovery.categories">
            {{i18n "categories.view_all"}}
            {{icon "external-link-alt"}}
          </LinkTo>
        </div>
      {{/if}}
    {{/if}}
  </template>
}
