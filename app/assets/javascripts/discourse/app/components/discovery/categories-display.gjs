import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import CategoriesAndLatestTopics from "discourse/components/categories-and-latest-topics";
import CategoriesAndTopTopics from "discourse/components/categories-and-top-topics";
import CategoriesBoxes from "discourse/components/categories-boxes";
import CategoriesBoxesWithTopics from "discourse/components/categories-boxes-with-topics";
import CategoriesOnly from "discourse/components/categories-only";
import CategoriesWithFeaturedTopics from "discourse/components/categories-with-featured-topics";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";
import PluginOutlet from "discourse/components/plugin-outlet";
import SubcategoriesWithFeaturedTopics from "discourse/components/subcategories-with-featured-topics";
import { MAX_UNOPTIMIZED_CATEGORIES } from "discourse/lib/constants";

const subcategoryComponents = {
  boxes_with_featured_topics: CategoriesBoxesWithTopics,
  boxes: CategoriesBoxes,
  rows_with_featured_topics: CategoriesWithFeaturedTopics,
  rows: CategoriesOnly,
};

const globalComponents = {
  categories_and_latest_topics_created_date: CategoriesAndLatestTopics,
  categories_and_latest_topics: CategoriesAndLatestTopics,
  categories_and_top_topics: CategoriesAndTopTopics,
  categories_boxes_with_topics: CategoriesBoxesWithTopics,
  categories_boxes: CategoriesBoxes,
  categories_only: CategoriesOnly,
  categories_with_featured_topics: CategoriesWithFeaturedTopics,
  subcategories_with_featured_topics: SubcategoriesWithFeaturedTopics,
};

export default class CategoriesDisplay extends Component {
  @service router;
  @service siteSettings;
  @service site;

  get #componentForSubcategories() {
    const parentCategory = this.args.parentCategory;
    const style = parentCategory.subcategory_list_style;
    const component = subcategoryComponents[style];

    if (!component) {
      // eslint-disable-next-line no-console
      console.error("Unknown subcategory list style: " + style);
      return CategoriesOnly;
    }

    return component;
  }

  get style() {
    let style = this.siteSettings.desktop_category_page_style;
    if (this.site.mobileView) {
      style = this.siteSettings.mobile_category_page_style;;
    }
    if (this.site.categories.length > MAX_UNOPTIMIZED_CATEGORIES) {
      style = "categories_only";
    }
    return style;
  }

  get #globalComponent() {
    const component = globalComponents[this.style];
    if (!component) {
      // eslint-disable-next-line no-console
      console.error("Unknown category list style: " + this.style);
      return CategoriesOnly;
    }

    return component;
  }

  get categoriesComponent() {
    if (
      this.args.parentCategory &&
      this.router.currentRouteName !== "discovery.subcategories"
    ) {
      return this.#componentForSubcategories;
    } else {
      return this.#globalComponent;
    }
  }

  get canLoadMore() {
    return (
      this.args.loadMore &&
      (this.site.lazy_load_categories ||
        this.site.categories.length > MAX_UNOPTIMIZED_CATEGORIES)
    );
  }

  <template>
    <PluginOutlet
      @name="above-discovery-categories"
      @connectorTagName="div"
      @outletArgs={{hash categories=@categories topics=@topics}}
    />
    {{#if this.canLoadMore}}
      <LoadMore
        @selector=".category:not(.muted-categories *)"
        @action={{@loadMore}}
      >
        <this.categoriesComponent
          @categories={{@categories}}
          @topics={{@topics}}
        />
        <ConditionalLoadingSpinner @condition={{@loadingMore}} />
      </LoadMore>
    {{else}}
      <this.categoriesComponent
        @categories={{@categories}}
        @topics={{@topics}}
      />
    {{/if}}
  </template>
}
