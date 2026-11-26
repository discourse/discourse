import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";

export default class ContextCategoryNavigation extends Component {
  @service site;

  get parentCategory() {
    const parent = this.args.category?.parentCategory;
    return parent?.isHidden ? null : parent;
  }

  get categories() {
    const category = this.args.category;
    const categories = category
      ? (this.parentCategory ?? category).subcategories
      : this.site.categoriesList;
    return (categories ?? []).filter(
      (item) =>
        (category || !item.parent_category_id) &&
        !item.isHidden &&
        !item.isUncategorizedCategory
    );
  }

  <template>
    <nav
      aria-label={{if
        @category
        @category.displayName
        (i18n "sidebar.all_categories")
      }}
      class="context-category-navigation"
      ...attributes
    >
      {{#if @category}}
        {{#if this.parentCategory}}
          <a href={{this.parentCategory.url}}>
            {{dCategoryBadge this.parentCategory hideParent=true}}
          </a>
        {{/if}}
        <h2>{{@category.displayName}}</h2>
        {{#if @category.descriptionText}}
          <p
            class="context-category__description"
          >{{@category.descriptionText}}</p>
        {{/if}}
      {{else}}
        <h2>{{i18n "page_shell.all_topics"}}</h2>
      {{/if}}
      {{#if this.categories.length}}
        <ul class="context-category-navigation__list">
          {{#each this.categories key="id" as |category|}}
            <li>
              <a
                aria-current={{if (eq category.id @category.id) "true"}}
                class="context-category-navigation__link"
                href={{category.url}}
              >
                {{dCategoryBadge category hideParent=true}}
                <span
                  class="context-category-navigation__count"
                  title={{i18n
                    "category_row.topic_count"
                    count=category.totalTopicCount
                  }}
                >{{dNumber category.totalTopicCount}}</span>
              </a>
            </li>
          {{/each}}
        </ul>
      {{/if}}
      {{#if @category}}
        <LinkTo @route="discovery.latest">{{i18n
            "page_shell.browse_all_topics"
          }}</LinkTo>
      {{/if}}
    </nav>
  </template>
}
