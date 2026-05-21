// @ts-check
import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { block } from "discourse/blocks";
import getURL from "discourse/lib/get-url";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import CategoryCard from "../components/blocks/category-card";

/**
 * Grid of selected category cards. The `categories` arg is a
 * pipe-separated string of category IDs (matches the meta-branded-theme
 * convention so authors can paste the same setting value across sites).
 * Each entry resolves to a Discourse category via `Category.findById`;
 * unresolvable IDs are dropped silently.
 */
@block("ve:featured-categories", {
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
        label: i18n("visual_editor.inspector.featured_categories.categories"),
        helpText: i18n(
          "visual_editor.inspector.featured_categories.categories_help"
        ),
      },
    },
    description: {
      type: "boolean",
      default: false,
      ui: {
        control: "toggle",
        label: i18n("visual_editor.inspector.featured_categories.description"),
      },
    },
    allCategoriesLink: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        label: i18n(
          "visual_editor.inspector.featured_categories.all_categories_link"
        ),
      },
    },
    allCategoriesLabel: {
      type: "string",
      default: "All categories",
      ui: {
        label: i18n(
          "visual_editor.inspector.featured_categories.all_categories_label"
        ),
      },
    },
  },
})
export default class VEFeaturedCategories extends Component {
  @cached
  get featuredCategories() {
    const ids = this.args.categories?.split("|").filter(Boolean) ?? [];
    return ids.map((id) => Category.findById(Number(id))).filter(Boolean);
  }

  get allCategoriesUrl() {
    return getURL("/categories");
  }

  <template>
    <div class="ve-featured-categories">
      <div class="ve-featured-categories__grid">
        {{#each this.featuredCategories as |category|}}
          <CategoryCard
            @category={{category}}
            @href={{category.url}}
            @showDescription={{@description}}
            @description={{category.description_excerpt}}
            @class={{concat
              "ve-featured-categories__card"
              (if @description " ve-featured-categories__card--has-description")
            }}
          />
        {{/each}}
      </div>

      {{#if @allCategoriesLink}}
        <div class="ve-featured-categories__footer">
          <a
            class="ve-featured-categories__all-link"
            href={{this.allCategoriesUrl}}
          >
            {{@allCategoriesLabel}}
          </a>
        </div>
      {{/if}}
    </div>
  </template>
}
