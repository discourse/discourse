// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import CategoryLogo from "discourse/components/category-logo";
import CategoryCard from "discourse/lib/blocks/-internals/category-card";
import Category from "discourse/models/category";
import { categoryLinkHTML } from "discourse/ui-kit/helpers/d-category-link";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * Category-page banner showing the current category's logo, title,
 * optional description, and optional subcategory grid. Reads
 * `router.currentRoute.params.category_slug_path_with_id` to detect
 * which category to render; renders nothing outside category routes.
 *
 * Visibility is intentionally driven by the route rather than the block
 * conditions system so the block can simply be dropped on a general
 * outlet (`main-outlet-blocks`) and stay invisible elsewhere.
 */
@block("category-banner", {
  thumbnail: () => import("discourse/blocks/thumbnails/category-banner"),
  displayName: "Category banner",
  icon: "folder",
  category: "Discourse data",
  description:
    "Banner for the current category page — logo, title, description, and subcategories.",
  args: {
    showLogo: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        label: i18n("blocks.builtin.category_banner.show_logo"),
      },
    },
    showIcon: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        label: i18n("blocks.builtin.category_banner.show_icon"),
      },
    },
    showDescription: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        label: i18n("blocks.builtin.category_banner.show_description"),
      },
    },
  },
})
export default class CategoryBanner extends Component {
  @service router;

  @tracked category = null;
  /**
   * Discourse renders an intermediate `*.loading` route between
   * navigating to a new category and the destination route settling.
   * During that window the URL params haven't transferred yet — so we
   * latch onto the previous category until the new one resolves,
   * avoiding a flash of empty banner.
   */
  @tracked _keepInLoadingRoute = false;

  /**
   * The current category's slug-with-ID URL segment, read off the
   * router's current-route params. `undefined` outside category routes.
   *
   * @returns {string|undefined}
   */
  get categorySlugPathWithID() {
    return this.router?.currentRoute?.params?.category_slug_path_with_id;
  }

  /**
   * Whether the banner should render at all. True on category routes and
   * during the brief `*.loading` window between category navigations
   * (see the `_keepInLoadingRoute` field's JSDoc for context).
   *
   * @returns {boolean}
   */
  get shouldRender() {
    return (
      this.categorySlugPathWithID ||
      (this._keepInLoadingRoute &&
        this.router.currentRoute.name.includes("loading"))
    );
  }

  /**
   * Whether the banner is in a route that should keep its existing
   * category data loaded. Used by `loadCategory()` to decide whether to
   * fetch fresh data or hold onto the previous category during loading
   * transitions.
   *
   * @returns {boolean}
   */
  get isVisible() {
    if (this.categorySlugPathWithID) {
      return true;
    }
    if (this.router.currentRoute.name.includes("loading")) {
      return this._keepInLoadingRoute;
    }
    return false;
  }

  /**
   * Inline style with the category's brand colours, exposed as CSS custom
   * properties so the stylesheet can theme the banner without touching
   * inline-style specificity.
   *
   * @returns {ReturnType<typeof trustHTML>}
   */
  get safeStyle() {
    return trustHTML(
      `--d-block-category-banner-background: #${this.category.color}; ` +
        `--d-block-category-banner-color: #${this.category.text_color};`
    );
  }

  /**
   * Whether the description region should appear. Honours the
   * `showDescription` arg and also collapses for categories without any
   * description text.
   *
   * @returns {boolean}
   */
  get displayCategoryDescription() {
    return this.args.showDescription && this.category.description?.length > 0;
  }

  /**
   * Whether to render the category's icon (or emoji) in the heading.
   * Requires both the `showIcon` arg AND a matching `style_type` /
   * payload on the category itself.
   *
   * @returns {boolean}
   */
  get showCategoryIcon() {
    if (!this.args.showIcon) {
      return false;
    }
    const hasIcon = this.category.style_type === "icon" && this.category.icon;
    const hasEmoji =
      this.category.style_type === "emoji" && this.category.emoji;
    return hasIcon || hasEmoji;
  }

  /**
   * HTML for the category-name pill (lock icon, colour swatch, name).
   * Delegates to core's `categoryLinkHTML`, but with `link: false` so
   * the badge is presentational only — the surrounding heading already
   * carries the link semantics.
   *
   * @returns {ReturnType<typeof categoryLinkHTML>}
   */
  get categoryNameBadge() {
    return categoryLinkHTML(this.category, {
      allowUncategorized: true,
      link: false,
    });
  }

  /**
   * Whether the current category has subcategories worth listing in the
   * banner's secondary region.
   *
   * @returns {boolean}
   */
  get hasSubcategories() {
    return this.category?.subcategories?.length > 0;
  }

  /**
   * Resolves the current route's category and latches the loading-route
   * fallback flag (see `_keepInLoadingRoute`). Triggered by `did-insert`
   * / `did-update` modifiers so the category refreshes on every visible
   * route change.
   */
  @action
  loadCategory() {
    if (!this.isVisible) {
      return;
    }
    if (this.categorySlugPathWithID) {
      this.category = Category.findBySlugPathWithID(
        this.categorySlugPathWithID
      );
      this._keepInLoadingRoute = true;
    } else if (!this.router.currentRoute.name.includes("loading")) {
      this._keepInLoadingRoute = false;
    }
  }

  <template>
    {{#if this.shouldRender}}
      <div
        class={{dConcatClass
          "d-block-category-banner"
          (if this.category this.category.slug)
        }}
        style={{if this.category this.safeStyle}}
        {{didInsert this.loadCategory}}
        {{didUpdate this.loadCategory this.isVisible}}
      >
        {{#if this.category}}
          <div class="d-block-category-banner__content">
            {{#if @showLogo}}
              <CategoryLogo
                class="d-block-category-banner__logo"
                @category={{this.category}}
              />
            {{/if}}

            <h2 class="d-block-category-banner__title">
              {{#if this.showCategoryIcon}}
                {{this.categoryNameBadge}}
              {{else}}
                {{#if this.category.read_restricted}}
                  {{dIcon "lock"}}
                {{/if}}
                {{this.category.name}}
              {{/if}}
            </h2>

            {{#if this.displayCategoryDescription}}
              <div class="d-block-category-banner__description">
                <div class="cooked">
                  {{trustHTML this.category.description}}
                </div>
              </div>
            {{/if}}

            {{#if this.hasSubcategories}}
              <ul
                class="d-block-category-banner__subcategories"
                aria-label="Subcategories"
              >
                {{#each this.category.subcategories as |subcategory|}}
                  <li class="d-block-category-banner__subcategory">
                    <CategoryCard
                      @category={{subcategory}}
                      @href={{subcategory.url}}
                      @class="d-block-category-banner__subcategory-card"
                    />
                  </li>
                {{/each}}
              </ul>
            {{/if}}
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
