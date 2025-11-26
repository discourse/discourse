import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { block } from "discourse/blocks";
import CategoryLogo from "discourse/components/category-logo";
import bodyClass from "discourse/helpers/body-class";
import { categoryLinkHTML } from "discourse/helpers/category-link";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import Category from "discourse/models/category";

@block("category-banner")
export default class BlockCategoryBanner extends Component {
  @service router;

  @tracked category = null;
  @tracked keepDuringLoadingRoute = false;

  constructor() {
    super(...arguments);
  }

  get categorySlugPathWithID() {
    return this.router?.currentRoute?.params?.category_slug_path_with_id;
  }

  get shouldRender() {
    return (
      this.categorySlugPathWithID ||
      (this.keepDuringLoadingRoute &&
        this.router.currentRoute.name.includes("loading"))
    );
  }

  get isVisible() {
    if (this.categorySlugPathWithID) {
      return true;
    } else if (this.router.currentRoute.name.includes("loading")) {
      return this.keepDuringLoadingRoute;
    }
    return false;
  }

  get safeStyle() {
    return htmlSafe(
      `--category-banner-background: #${this.category.color}; --category-banner-color: #${this.category.text_color};`
    );
  }

  get displayCategoryDescription() {
    return this.args.showDescription && this.category.description?.length > 0;
  }

  get showCategoryIcon() {
    const hasIcon = this.category.style_type === "icon" && this.category.icon;
    const hasEmoji =
      this.category.style_type === "emoji" && this.category.emoji;

    if (this.args.showCategoryIcon && (hasIcon || hasEmoji)) {
      return true;
    } else {
      return false;
    }
  }

  get categoryNameBadge() {
    return categoryLinkHTML(this.category, {
      allowUncategorized: true,
      link: false,
    });
  }

  @action
  teardownComponent() {
    this.category = null;
  }

  @action
  getCategory() {
    if (!this.isVisible) {
      return;
    }

    if (this.categorySlugPathWithID) {
      this.category = Category.findBySlugPathWithID(
        this.categorySlugPathWithID
      );

      this.keepDuringLoadingRoute = true;
    } else {
      if (!this.router.currentRoute.name.includes("loading")) {
        return (this.keepDuringLoadingRoute = false);
      }
    }
  }

  <template>
    {{#if this.shouldRender}}
      {{bodyClass "block-category-banner"}}

      <div
        {{didInsert this.getCategory}}
        {{didUpdate this.getCategory this.isVisible}}
        {{willDestroy this.teardownComponent}}
        class={{concatClass
          "block-category-banner__container"
          (if this.category (concat this.category.slug))
        }}
        style={{if this.category this.safeStyle}}
      >
        {{#if this.category}}
          <div class="block-category-banner__layout">

            {{#if @showLogo}}
              <CategoryLogo
                class="block-category-banner__logo"
                @category={{this.category}}
              />
            {{/if}}

            <h2 class="block-category-banner__title">
              {{#if this.showCategoryIcon}}
                {{this.categoryNameBadge}}
              {{else}}
                {{#if this.category.read_restricted}}
                  {{icon "lock"}}
                {{/if}}
                {{this.category.name}}
              {{/if}}
            </h2>

            {{#if this.displayCategoryDescription}}
              <div class="block-category-banner__description">
                <div class="cooked">
                  {{htmlSafe this.category.description}}
                </div>
              </div>
            {{/if}}

          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
