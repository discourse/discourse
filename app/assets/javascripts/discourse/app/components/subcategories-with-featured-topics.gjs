import Component from "@ember/component";
import { htmlSafe } from "@ember/template";
import CategoryTitleLink from "discourse/components/category-title-link";
import ParentCategoryRow from "discourse/components/parent-category-row";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

export default class SubcategoriesWithFeaturedTopics extends Component {
  <template>
    {{#each this.categories as |category|}}
      {{#if this.site.mobileView}}
        <PluginOutlet
          @name="mobile-subcategories-with-featured-topics-list"
          @outletArgs={{lazyHash category=category}}
        >
          <div class="category-list subcategory-list with-topics">
            <div class="parent-category">
              <CategoryTitleLink @category={{category}} />
              <span class="stat" title={{category.statTitle}}>{{htmlSafe
                  category.stat
                }}</span>
            </div>
            <div class="subcategories">
              {{#each category.serializedSubcategories as |subCategory|}}
                <ParentCategoryRow
                  @category={{subCategory}}
                  @showTopics={{true}}
                />
              {{else}}
                {{! No subcategories... so just show the parent to avoid confusion }}
                <ParentCategoryRow
                  @category={{category}}
                  @showTopics={{true}}
                />
              {{/each}}
            </div>
          </div>
        </PluginOutlet>
      {{else}}
        <PluginOutlet
          @name="subcategories-with-featured-topics-list"
          @outletArgs={{lazyHash category=category}}
        >
          <table class="category-list subcategory-list with-topics">
            <thead>
              <tr>
                <th class="parent-category">
                  <CategoryTitleLink @category={{category}} />
                  <span class="stat" title={{category.statTitle}}>{{htmlSafe
                      category.stat
                    }}</span>
                </th>
                <th class="topics">{{i18n "categories.topics"}}</th>
                <th class="latest">{{i18n "categories.latest"}}</th>
              </tr>
            </thead>
            <tbody aria-labelledby="categories-only-category">
              {{#each category.serializedSubcategories as |subCategory|}}
                <ParentCategoryRow
                  @category={{subCategory}}
                  @showTopics={{true}}
                />
              {{else}}
                {{! No subcategories... so just show the parent to avoid confusion }}
                <ParentCategoryRow
                  @category={{category}}
                  @showTopics={{true}}
                />
              {{/each}}
            </tbody>
          </table>
        </PluginOutlet>
      {{/if}}
    {{/each}}
  </template>
}
