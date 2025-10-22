import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";
import { number } from "discourse/lib/formatter";
import LegacyArrayLikeObject from "discourse/lib/legacy-array-like-object";
import PreloadStore from "discourse/lib/preload-store";
import { trackedArray } from "discourse/lib/tracked-tools";
import Site from "discourse/models/site";
import Topic from "discourse/models/topic";
import { i18n } from "discourse-i18n";

const STAT_PERIODS = ["week", "month"];

/**
 * Represents a list of categories with their related metadata and functionality
 */
export default class CategoryList extends LegacyArrayLikeObject {
  /**
   * Creates category objects from API result data
   *
   * @param {Object} store - The store instance
   * @param {Object} result - The API result containing category data
   * @param {Object} parentCategory - Optional parent category
   * @returns {CategoryList} A new CategoryList instance with the processed categories
   */
  static categoriesFrom(store, result, parentCategory = null) {
    // Find the period that is most relevant
    const list = result?.category_list?.categories || [];
    const statPeriod =
      STAT_PERIODS.find(
        (period) =>
          list.filter((c) => c?.[`topics_${period}`] > 0).length >=
          list.length * 0.66
      ) || "all";

    // Update global category list to make sure that `findById` works as
    // expected later
    list.forEach((c) => Site.current().updateCategory(c));

    const categories = CategoryList.create({ store });
    list.forEach((c) => {
      c = this._buildCategoryResult(c, statPeriod);
      if (
        (parentCategory && c.parent_category_id === parentCategory.id) ||
        (!parentCategory && !c.parent_category_id)
      ) {
        categories.content.push(c);
      }
    });
    return categories;
  }

  /**
   * Builds a category result object with stats and topic data
   * @param {Object} rawCategoryData - The raw category data
   * @param {string} statPeriod - The period to use for stats ('week', 'month', or 'all')
   * @returns {Category} The processed category object
   * @private
   */
  static _buildCategoryResult(rawCategoryData, statPeriod) {
    if (rawCategoryData.topics?.length) {
      rawCategoryData.topics = rawCategoryData.topics.map((t) =>
        Topic.create(t)
      );
    }

    const stat = rawCategoryData[`topics_${statPeriod}`];
    const isTimedPeriod = statPeriod === "week" || statPeriod === "month";
    if (isTimedPeriod && stat > 0) {
      const unit = i18n(`categories.topic_stat_unit.${statPeriod}`);

      rawCategoryData.stat = i18n("categories.topic_stat", {
        count: stat, // only used to correctly pluralize the string
        number: `<span class="value">${number(stat)}</span>`,
        unit: `<span class="unit">${unit}</span>`,
      });

      rawCategoryData.statTitle = i18n(
        `categories.topic_stat_sentence_${statPeriod}`,
        {
          count: stat,
        }
      );

      rawCategoryData.pickAll = false;
    } else {
      rawCategoryData.stat = `<span class="value">${number(rawCategoryData.topics_all_time)}</span>`;
      rawCategoryData.statTitle = i18n("categories.topic_sentence", {
        count: rawCategoryData.topics_all_time,
      });
      rawCategoryData.pickAll = true;
    }

    if (Site.current().mobileView) {
      rawCategoryData.statTotal = i18n("categories.topic_stat_all_time", {
        count: rawCategoryData.topics_all_time,
        number: `<span class="value">${number(rawCategoryData.topics_all_time)}</span>`,
      });
    }

    const record = Site.current().updateCategory(rawCategoryData);
    record.setupGroupsAndPermissions();
    return record;
  }

  /**
   * @deprecated Use list() instead
   */
  static listForParent(store, parentCategory) {
    deprecated(
      "The listForParent method of CategoryList is deprecated. Use list instead",
      { id: "discourse.category-list.listForParent" }
    );

    return CategoryList.list(store, parentCategory);
  }

  /**
   * Fetches and creates a list of categories
   *
   * @param {Object} store - The store instance
   * @param {Object} parentCategory - Optional parent category to filter by
   * @returns {Promise<CategoryList>} A promise that resolves to the CategoryList
   */
  static async list(store, parentCategory = null) {
    const result = await PreloadStore.getAndRemove(
      "categories_list",
      async () => {
        const data = {};
        if (parentCategory) {
          data.parent_category_id = parentCategory.id;
        }
        return ajax("/categories.json", { data });
      }
    );

    const categoryList = result?.category_list || {};
    return CategoryList.create({
      store,
      categories: this.categoriesFrom(store, result, parentCategory).content,
      parentCategory,
      can_create_category: categoryList.can_create_category,
      can_create_topic: categoryList.can_create_topic,
    });
  }

  /**
   * Creates a new CategoryList instance
   *
   * @param {Object} attrs - The attributes to initialize with
   * @returns {CategoryList} A new CategoryList instance
   */
  static create(attrs = {}) {
    const { categories, ...properties } = attrs;
    return super.create({ content: categories, ...properties });
  }

  @tracked can_create_category;
  @tracked can_create_topic;
  @tracked fetchedLastPage = false;
  @tracked isLoading = false;
  @tracked page = 1;
  @tracked parentCategory;
  @trackedArray topics;
  store;

  /**
   * @returns {Proxy} The proxied content for compatibility
   * @deprecated use the category list instance instead
   */
  get categories() {
    deprecated(
      "Using `CategoryList.categories` property is deprecated. Use `CategoryList.content` instead",
      { id: "discourse.category-list.categories" }
    );
    return this.content;
  }

  /**
   * Loads more categories from the server
   * @returns {Promise<void>}
   */
  @bind
  async loadMore() {
    if (this.isLoading || this.fetchedLastPage) {
      return;
    }

    this.isLoading = true;

    try {
      const nextPage = this.page + 1;
      const data = {
        page: nextPage,
        ...(this.parentCategory && {
          parent_category_id: this.parentCategory.id,
        }),
      };

      const result = await ajax("/categories.json", { data });

      this.page = nextPage;

      const newItems = CategoryList.categoriesFrom(
        this.store,
        result,
        this.parentCategory
      ).content;

      if (!newItems.length) {
        this.fetchedLastPage = true;
      } else {
        newItems.forEach((c) => this.content.push(c));
      }
    } finally {
      this.isLoading = false;
    }
  }
}
