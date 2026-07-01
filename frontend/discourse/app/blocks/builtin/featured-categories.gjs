// @ts-check
import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { block } from "discourse/blocks";
import FeaturedCategoriesThumbnail from "discourse/components/svg/blocks/featured-categories";
import CategoryCard from "discourse/lib/blocks/-internals/category-card";
import getURL from "discourse/lib/get-url";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";

/**
 * Grid of selected category cards. The `categories` arg is a
 * pipe-separated string of category IDs, so the same value can be pasted
 * across sites. Each entry resolves to a Discourse category via
 * `Category.findById`; unresolvable IDs are dropped silently.
 */
@block("featured-categories", {
  thumbnail: FeaturedCategoriesThumbnail,
  displayName: "Featured categories",
  icon: "folder-tree",
  category: "Discourse data",
  description: "A grid of selected category cards.",
  args: {
    categories: {
      type: "string",
      default: "",
      ui: {
        control: "category-select",
        label: i18n("blocks.builtin.featured_categories.categories"),
        helpText: i18n("blocks.builtin.featured_categories.categories_help"),
      },
    },
    description: {
      type: "boolean",
      default: false,
      ui: {
        control: "toggle",
        label: i18n("blocks.builtin.featured_categories.description"),
      },
    },
    allCategoriesLink: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        label: i18n("blocks.builtin.featured_categories.all_categories_link"),
      },
    },
    allCategoriesLabel: {
      type: "string",
      default: "All categories",
      ui: {
        label: i18n("blocks.builtin.featured_categories.all_categories_label"),
      },
    },
  },
})
export default class FeaturedCategories extends Component {
  /**
   * Resolves the pipe-separated `categories` arg into the matching set
   * of Discourse Category model instances. Empty / unparseable IDs are
   * silently dropped. `@cached` so re-renders during inline editing
   * don't repeat the `findById` lookups.
   *
   * @returns {Array<import("discourse/models/category").default>}
   */
  @cached
  get featuredCategories() {
    const ids = this.args.categories?.split("|").filter(Boolean) ?? [];
    return ids.map((id) => Category.findById(Number(id))).filter(Boolean);
  }

  /**
   * The resolved URL for the `/categories` index page, used by the
   * footer "All categories" link.
   *
   * @returns {string}
   */
  get allCategoriesUrl() {
    return getURL("/categories");
  }

  <template>
    <div class="d-block-featured-categories">
      <div class="d-block-featured-categories__grid">
        {{#each this.featuredCategories as |category|}}
          <CategoryCard
            @category={{category}}
            @href={{category.url}}
            @showDescription={{@description}}
            @description={{category.description_excerpt}}
            @class={{concat
              "d-block-featured-categories__card"
              (if
                @description
                " d-block-featured-categories__card--has-description"
              )
            }}
          />
        {{/each}}
      </div>

      {{#if @allCategoriesLink}}
        <div class="d-block-featured-categories__footer">
          <a
            class="d-block-featured-categories__all-link"
            href={{this.allCategoriesUrl}}
          >
            {{@allCategoriesLabel}}
          </a>
        </div>
      {{/if}}
    </div>
  </template>
}
