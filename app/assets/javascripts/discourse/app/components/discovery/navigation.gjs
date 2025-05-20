import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AddCategoryTagClasses from "discourse/components/add-category-tag-classes";
import CategoryLogo from "discourse/components/category-logo";
import DNavigation from "discourse/components/d-navigation";
import AccessibleDiscoveryHeading from "discourse/components/discovery/accessible-discovery-heading";
import ReorderCategories from "discourse/components/modal/reorder-categories";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import concatClass from "discourse/helpers/concat-class";
import dirSpan from "discourse/helpers/dir-span";
import lazyHash from "discourse/helpers/lazy-hash";
import { calculateFilterMode } from "discourse/lib/filter-mode";
import { TRACKED_QUERY_PARAM_VALUE } from "discourse/lib/topic-list-tracked-filter";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";

export default class DiscoveryNavigation extends Component {
  @service router;
  @service currentUser;
  @service modal;

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
    return this.currentUser?.can_create_topic;
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

  @action
  editCategory() {
    DiscourseURL.routeTo(`/c/${Category.slugFor(this.args.category)}/edit`);
  }

  @action
  createCategory() {
    this.router.transitionTo("newCategory");
  }

  @action
  reorderCategories() {
    this.modal.show(ReorderCategories);
  }

  <template>
    <AddCategoryTagClasses
      @category={{@category}}
      @tags={{if @tag (array @tag.id)}}
    />

    <AccessibleDiscoveryHeading
      @category={{@category}}
      @tag={{@tag}}
      @additionalTags={{@additionalTags}}
      @filter={{this.filterMode}}
    />

    {{#if @category}}
      <PluginOutlet
        @name="above-category-heading"
        @outletArgs={{lazyHash category=@category tag=@tag}}
      />

      <section class="category-heading">
        {{#if @category.uploaded_logo.url}}
          <CategoryLogo @category={{@category}} />
          {{#if @category.description}}
            <p>{{dirSpan @category.description htmlSafe="true"}}</p>
          {{/if}}
        {{/if}}

        <span>
          <PluginOutlet
            @name="category-heading"
            @connectorTagName="div"
            @outletArgs={{lazyHash category=@category tag=@tag}}
          />
        </span>
      </section>
    {{/if}}

    {{bodyClass this.bodyClass}}

    <section
      class={{concatClass
        "navigation-container"
        (if @category "category-navigation")
      }}
    >
      <DNavigation
        @category={{@category}}
        @tag={{@tag}}
        @additionalTags={{@additionalTags}}
        @filterMode={{this.filterMode}}
        @noSubcategories={{@noSubcategories}}
        @canCreateTopic={{this.canCreateTopic}}
        @canCreateTopicOnTag={{@canCreateTopicOnTag}}
        @createTopic={{@createTopic}}
        @createTopicDisabled={{@createTopicDisabled}}
        @draftCount={{this.currentUser.draft_count}}
        @editCategory={{this.editCategory}}
        @showCategoryAdmin={{@showCategoryAdmin}}
        @createCategory={{this.createCategory}}
        @reorderCategories={{this.reorderCategories}}
        @canBulkSelect={{@canBulkSelect}}
        @bulkSelectHelper={{@bulkSelectHelper}}
        @skipCategoriesNavItem={{this.skipCategoriesNavItem}}
        @toggleInfo={{@toggleTagInfo}}
        @tagNotification={{@tagNotification}}
        @model={{@model}}
        @showDismissRead={{@showDismissRead}}
        @showResetNew={{@showResetNew}}
        @dismissRead={{@dismissRead}}
        @resetNew={{@resetNew}}
      />

      {{#if @category}}
        <PluginOutlet
          @name="category-navigation"
          @connectorTagName="div"
          @outletArgs={{lazyHash category=@category tag=@tag}}
        />
      {{/if}}

      {{#if @tag}}
        <PluginOutlet
          @name="tag-navigation"
          @connectorTagName="div"
          @outletArgs={{lazyHash category=@category tag=@tag}}
        />
      {{/if}}
    </section>
  </template>
}
