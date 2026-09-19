import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import AddCategoryTagClasses from "discourse/components/add-category-tag-classes";
import CategoryLogo from "discourse/components/category-logo";
import DNavigation from "discourse/components/d-navigation";
import AccessibleDiscoveryHeading from "discourse/components/discovery/accessible-discovery-heading";
import ReorderCategories from "discourse/components/modal/reorder-categories";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import categoryColorVariable from "discourse/helpers/category-color-variable";
import lazyHash from "discourse/helpers/lazy-hash";
import { calculateFilterMode } from "discourse/lib/filter-mode";
import { TRACKED_QUERY_PARAM_VALUE } from "discourse/lib/topic-list-tracked-filter";
import { applyValueTransformer } from "discourse/lib/transformer";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class DiscoveryNavigation extends Component {
  @service categoryTypeChooser;
  @service currentUser;
  @service modal;
  @service router;
  @service siteSettings;

  get filterMode() {
    return calculateFilterMode({
      category: this.args.category,
      filterType: this.args.filterType,
      noSubcategories: this.args.noSubcategories,
    });
  }

  get skipCategoriesNavItem() {
    return this.router.currentRoute.queryParams.f === TRACKED_QUERY_PARAM_VALUE;
  }

  get canCreateTopic() {
    let value = this.currentUser?.can_create_topic ?? false;

    if (
      value &&
      this.siteSettings.hide_disabled_create_topic_button &&
      this.args.createTopicDisabled
    ) {
      value = false;
    }

    return applyValueTransformer("can-create-topic-button", value, {
      category: this.args.category,
      tag: this.args.tag,
      createTopicDisabled: this.args.createTopicDisabled,
    });
  }

  get bodyClass() {
    if (this.args.tag) {
      return [
        "tags-page",
        this.args.additionalTags ? "tags-intersection" : null,
      ]
        .filter(Boolean)
        .join(" ");
    } else if (this.filterMode === "categories") {
      return "navigation-categories";
    } else if (this.args.category) {
      return "navigation-category";
    } else {
      return "navigation-topics";
    }
  }

  get headingClasses() {
    return dConcatClass(
      "category-heading",
      this.args.category?.uploaded_logo?.url
        ? "--has-logo discovery-heading"
        : null
    );
  }

  @action
  editCategory() {
    DiscourseURL.routeTo(`/c/${Category.slugFor(this.args.category)}/edit`);
  }

  @action
  createCategory() {
    this.categoryTypeChooser.createCategory();
  }

  @action
  reorderCategories() {
    this.modal.show(ReorderCategories);
  }

  <template>
    <AddCategoryTagClasses
      @category={{@category}}
      @tags={{if @tag (array @tag.name)}}
    />

    <AccessibleDiscoveryHeading
      @additionalTags={{@additionalTags}}
      @category={{@category}}
      @filter={{this.filterMode}}
      @tag={{@tag}}
    />

    {{#if @category}}
      <PluginOutlet
        @name="above-category-heading"
        @outletArgs={{lazyHash category=@category tag=@tag}}
      />

      <section
        class={{this.headingClasses}}
        style={{categoryColorVariable @category.color}}
      >
        {{#if @category.uploaded_logo.url}}
          <CategoryLogo
            class="category-heading__logo"
            @category={{@category}}
          />
          {{#if @category.description}}
            <div class="category-heading__content">
              {{dCategoryBadge @category class="category-heading__badge"}}
              <p class="category-heading__description">
                {{trustHTML @category.description}}
              </p>
            </div>
          {{/if}}
        {{/if}}

        <PluginOutlet
          @connectorTagName="div"
          @name="category-heading"
          @outletArgs={{lazyHash category=@category tag=@tag}}
        />

      </section>
    {{/if}}

    {{bodyClass this.bodyClass}}

    <section
      class={{dConcatClass
        "navigation-container"
        (if @category "category-navigation")
      }}
    >
      <DNavigation
        @additionalTags={{@additionalTags}}
        @bulkSelectHelper={{@bulkSelectHelper}}
        @canBulkSelect={{@canBulkSelect}}
        @canCreateTopic={{this.canCreateTopic}}
        @canCreateTopicOnTag={{@canCreateTopicOnTag}}
        @category={{@category}}
        @createCategory={{this.createCategory}}
        @createTopic={{@createTopic}}
        @createTopicDisabled={{@createTopicDisabled}}
        @dismissRead={{@dismissRead}}
        @draftCount={{this.currentUser.draft_count}}
        @editCategory={{this.editCategory}}
        @filterMode={{this.filterMode}}
        @loadingTagInfo={{@loadingTagInfo}}
        @model={{@model}}
        @noSubcategories={{@noSubcategories}}
        @reorderCategories={{this.reorderCategories}}
        @resetNew={{@resetNew}}
        @showCategoryAdmin={{@showCategoryAdmin}}
        @showDismissRead={{@showDismissRead}}
        @showResetNew={{@showResetNew}}
        @showTagInfo={{@showTagInfo}}
        @skipCategoriesNavItem={{this.skipCategoriesNavItem}}
        @tag={{@tag}}
        @tagNotification={{@tagNotification}}
        @toggleTagInfo={{@toggleTagInfo}}
      />

      {{#if @category}}
        <PluginOutlet
          @connectorTagName="div"
          @name="category-navigation"
          @outletArgs={{lazyHash category=@category tag=@tag}}
        />
      {{/if}}

      {{#if @tag}}
        <PluginOutlet
          @connectorTagName="div"
          @name="tag-navigation"
          @outletArgs={{lazyHash category=@category tag=@tag}}
        />
      {{/if}}
    </section>
  </template>
}
