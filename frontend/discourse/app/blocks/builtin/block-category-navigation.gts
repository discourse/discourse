import Component from "@glimmer/component";
import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { service } from "@ember/service";
import { type TrustedHTML, trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import BlockPanel from "discourse/blocks/block-panel";
import { number } from "discourse/lib/formatter";
import getURL from "discourse/lib/get-url";
import type Category from "discourse/models/category";
import type Site from "discourse/models/site";
import type DiscoveryService from "discourse/services/discovery";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const ALL_CATEGORIES_URLS = ["/", "/latest", "/categories"];

/**
 * A category with the server-provided attributes the block reads that aren't
 * declared on the base model type.
 */
type NavigationCategory = Category & {
  id: number;
  color?: string;
  emoji?: string;
  icon?: string;
  style_type?: string;
  parent_category_id?: number | null;
  topic_count?: number;
  parentCategory?: NavigationCategory | null;
  subcategories?: NavigationCategory[];
};

interface CategoryMarkSignature {
  Args: {
    category: NavigationCategory;
    style: TrustedHTML;
  };
}

// The category's mark in the style it uses: its emoji, its icon, or a colour
// square.
const CategoryMark: TemplateOnlyComponent<CategoryMarkSignature> = <template>
  <span
    aria-hidden="true"
    class="d-block-category-navigation__mark --{{@category.style_type}}"
    style={{@style}}
  >
    {{#if (eq @category.style_type "emoji")}}
      {{dEmoji @category.emoji}}
    {{else if (eq @category.style_type "icon")}}
      {{dIcon @category.icon}}
    {{else}}
      <span class="d-block-category-navigation__square"></span>
    {{/if}}
  </span>
</template>;

function eq(a: unknown, b: unknown): boolean {
  return a === b;
}

interface BlockCategoryNavigationSignature {
  Args: {
    title?: string;
    icon?: string;
    showDescription?: boolean;
    showTopicCounts?: boolean;
    allCategoriesUrl?: string;
  };
}

/**
 * Navigation within the current top-level category: the category with its
 * description, and its subcategories with the current one highlighted. A
 * subcategory page belongs to its parent. On lists without a category it
 * lists every top-level category instead, under the title.
 */
@block("category-navigation", {
  displayName: "Category navigation",
  icon: "compass",
  category: "community",
  description:
    "The current top-level category and its subcategories, or all top-level categories.",
  args: {
    title: {
      type: "string",
      default: "Categories",
      ui: { label: i18n("blocks.builtin.category_navigation.title") },
    },
    icon: {
      type: "string",
      default: "compass",
      ui: {
        control: "icon",
        label: i18n("blocks.builtin.category_navigation.icon"),
      },
    },
    showDescription: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        label: i18n("blocks.builtin.category_navigation.show_description"),
      },
    },
    showTopicCounts: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        label: i18n("blocks.builtin.category_navigation.show_topic_counts"),
      },
    },
    allCategoriesUrl: {
      type: "string",
      default: "/",
      enum: ALL_CATEGORIES_URLS,
      ui: {
        control: "select",
        label: i18n("blocks.builtin.category_navigation.all_categories_url"),
      },
    },
  },
})
export default class BlockCategoryNavigation extends Component<BlockCategoryNavigationSignature> {
  @service declare discovery: DiscoveryService;
  @service declare site: Site;

  isCurrent = (category: NavigationCategory): boolean =>
    category.id === this.category?.id;

  markStyle = (category: NavigationCategory): TrustedHTML =>
    trustHTML(`--category-badge-color: #${category.color}`);

  get category(): NavigationCategory | null {
    return (this.discovery.category as NavigationCategory | undefined) ?? null;
  }

  get topLevel(): NavigationCategory | null {
    return this.category?.parentCategory ?? this.category;
  }

  get subcategories(): NavigationCategory[] {
    return this.visible(this.topLevel?.subcategories ?? []);
  }

  get topLevelCategories(): NavigationCategory[] {
    return this.visible(
      (this.site.categories as NavigationCategory[]).filter(
        (category) => !category.parent_category_id
      )
    );
  }

  get allCategoriesUrl(): string {
    return getURL(this.args.allCategoriesUrl ?? "/");
  }

  visible(categories: NavigationCategory[]): NavigationCategory[] {
    return categories.filter(
      (category) => !category.isHidden && !category.isUncategorizedCategory
    );
  }

  <template>
    {{#if this.topLevel}}
      <BlockPanel class="d-block-category-navigation">
        <:header>
          <div
            class="d-block-category-navigation__intro
              {{if (this.isCurrent this.topLevel) '--current'}}"
          >
            <a
              aria-current={{if (this.isCurrent this.topLevel) "page"}}
              class="d-block-category-navigation__head"
              href={{this.topLevel.url}}
            >
              <CategoryMark
                @category={{this.topLevel}}
                @style={{this.markStyle this.topLevel}}
              />
              <span
                class="d-block-category-navigation__name"
              >{{this.topLevel.displayName}}</span>
            </a>
            {{#if @showDescription}}
              {{#if this.topLevel.descriptionText}}
                <p
                  class="d-block-category-navigation__description"
                >{{this.topLevel.descriptionText}}</p>
              {{/if}}
            {{/if}}
          </div>
        </:header>
        <:content>
          {{#if this.subcategories.length}}
            <ul class="d-block-category-navigation__list">
              {{#each this.subcategories as |subcategory|}}
                <li
                  class="d-block-category-navigation__item
                    {{if (this.isCurrent subcategory) '--current'}}"
                >
                  <a
                    aria-current={{if (this.isCurrent subcategory) "page"}}
                    class="d-block-category-navigation__link"
                    href={{subcategory.url}}
                  >
                    <CategoryMark
                      @category={{subcategory}}
                      @style={{this.markStyle subcategory}}
                    />
                    <span
                      class="d-block-category-navigation__name"
                    >{{subcategory.displayName}}</span>
                    {{#if @showTopicCounts}}
                      <span class="d-block-category-navigation__count">
                        {{i18n
                          "blocks.builtin.category_navigation.topic_count"
                          count=subcategory.topic_count
                          formatted_number=(number subcategory.topic_count)
                        }}
                      </span>
                    {{/if}}
                  </a>
                </li>
              {{/each}}
            </ul>
          {{/if}}
        </:content>
        <:footer>
          <a class="d-block-panel__link" href={{this.allCategoriesUrl}}>
            {{i18n "blocks.builtin.category_navigation.all_categories"}}
          </a>
        </:footer>
      </BlockPanel>
    {{else if this.topLevelCategories.length}}
      <BlockPanel
        class="d-block-category-navigation --global"
        @icon={{@icon}}
        @title={{@title}}
      >
        <:content>
          <ul class="d-block-category-navigation__list">
            {{#each this.topLevelCategories as |category|}}
              <li class="d-block-category-navigation__item">
                <a
                  class="d-block-category-navigation__link"
                  href={{category.url}}
                >
                  <CategoryMark
                    @category={{category}}
                    @style={{this.markStyle category}}
                  />
                  <span
                    class="d-block-category-navigation__name"
                  >{{category.displayName}}</span>
                  {{#if @showTopicCounts}}
                    <span class="d-block-category-navigation__count">
                      {{i18n
                        "blocks.builtin.category_navigation.topic_count"
                        count=category.totalTopicCount
                        formatted_number=(number category.totalTopicCount)
                      }}
                    </span>
                  {{/if}}
                </a>
              </li>
            {{/each}}
          </ul>
        </:content>
      </BlockPanel>
    {{/if}}
  </template>
}
