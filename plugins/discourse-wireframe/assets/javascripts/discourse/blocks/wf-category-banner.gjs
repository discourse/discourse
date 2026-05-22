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
import Category from "discourse/models/category";
import { categoryLinkHTML } from "discourse/ui-kit/helpers/d-category-link";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import CategoryCard from "../components/blocks/category-card";

/**
 * Category-page banner showing the current category's logo, title,
 * optional description, and optional subcategory grid. Reads
 * `router.currentRoute.params.category_slug_path_with_id` to detect
 * which category to render; renders nothing outside category routes.
 *
 * Visibility is intentionally driven by the route rather than the
 * editor's conditions system so the block can simply be dropped on a
 * general outlet (`main-outlet-blocks`) and stay invisible elsewhere —
 * matches the original meta-branded-theme behaviour.
 */
@block("wf:category-banner", {
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
        label: i18n("wireframe.inspector.category_banner.show_logo"),
      },
    },
    showIcon: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        label: i18n("wireframe.inspector.category_banner.show_icon"),
      },
    },
    showDescription: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        label: i18n("wireframe.inspector.category_banner.show_description"),
      },
    },
  },
})
export default class WFCategoryBanner extends Component {
  @service router;

  @tracked category = null;
  /**
   * Discourse renders an intermediate `*.loading` route between
   * navigating to a new category and the destination route settling.
   * During that window the URL params haven't transferred yet — so we
   * latch onto the previous category until the new one resolves,
   * avoiding a flash of empty banner.
   */
  @tracked keepInLoadingRoute = false;

  get categorySlugPathWithID() {
    return this.router?.currentRoute?.params?.category_slug_path_with_id;
  }

  get shouldRender() {
    return (
      this.categorySlugPathWithID ||
      (this.keepInLoadingRoute &&
        this.router.currentRoute.name.includes("loading"))
    );
  }

  get isVisible() {
    if (this.categorySlugPathWithID) {
      return true;
    }
    if (this.router.currentRoute.name.includes("loading")) {
      return this.keepInLoadingRoute;
    }
    return false;
  }

  get safeStyle() {
    return trustHTML(
      `--wf-category-banner-background: #${this.category.color}; ` +
        `--wf-category-banner-color: #${this.category.text_color};`
    );
  }

  get displayCategoryDescription() {
    return this.args.showDescription && this.category.description?.length > 0;
  }

  get showCategoryIcon() {
    if (!this.args.showIcon) {
      return false;
    }
    const hasIcon = this.category.style_type === "icon" && this.category.icon;
    const hasEmoji =
      this.category.style_type === "emoji" && this.category.emoji;
    return hasIcon || hasEmoji;
  }

  get categoryNameBadge() {
    return categoryLinkHTML(this.category, {
      allowUncategorized: true,
      link: false,
    });
  }

  get hasSubcategories() {
    return this.category?.subcategories?.length > 0;
  }

  @action
  loadCategory() {
    if (!this.isVisible) {
      return;
    }
    if (this.categorySlugPathWithID) {
      this.category = Category.findBySlugPathWithID(
        this.categorySlugPathWithID
      );
      this.keepInLoadingRoute = true;
    } else if (!this.router.currentRoute.name.includes("loading")) {
      this.keepInLoadingRoute = false;
    }
  }

  <template>
    {{#if this.shouldRender}}
      <div
        class={{dConcatClass
          "wf-category-banner"
          (if this.category this.category.slug)
        }}
        style={{if this.category this.safeStyle}}
        {{didInsert this.loadCategory}}
        {{didUpdate this.loadCategory this.isVisible}}
      >
        {{#if this.category}}
          <div class="wf-category-banner__content">
            {{#if @showLogo}}
              <CategoryLogo
                class="wf-category-banner__logo"
                @category={{this.category}}
              />
            {{/if}}

            <h2 class="wf-category-banner__title">
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
              <div class="wf-category-banner__description">
                <div class="cooked">
                  {{trustHTML this.category.description}}
                </div>
              </div>
            {{/if}}

            {{#if this.hasSubcategories}}
              <ul
                class="wf-category-banner__subcategories"
                aria-label="Subcategories"
              >
                {{#each this.category.subcategories as |subcategory|}}
                  <li class="wf-category-banner__subcategory">
                    <CategoryCard
                      @category={{subcategory}}
                      @href={{subcategory.url}}
                      @class="wf-category-banner__subcategory-card"
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
