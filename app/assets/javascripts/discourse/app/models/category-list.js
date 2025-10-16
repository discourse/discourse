import { tracked } from "@glimmer/tracking";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";
import { number } from "discourse/lib/formatter";
import PreloadStore from "discourse/lib/preload-store";
import { trackedArray } from "discourse/lib/tracked-tools";
import Site from "discourse/models/site";
import Topic from "discourse/models/topic";
import { i18n } from "discourse-i18n";

const STAT_PERIODS = ["week", "month"];

/**
 * Represents a list of categories with their related metadata and functionality
 */
export default class CategoryList {
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
        categories.push(c);
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
      categories: this.categoriesFrom(store, result, parentCategory),
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
  static create(attrs) {
    return new CategoryList(attrs);
  }

  @tracked can_create_category;
  @tracked can_create_topic;
  @tracked fetchedLastPage = false;
  @tracked isLoading = false;
  @tracked page = 1;
  @tracked parentCategory;
  @trackedArray topics;
  store;

  #items;
  #proxy;

  /**
   * Initializes a new CategoryList instance
   *
   * @param {Object} param0 - The initialization parameters
   * @param {Array} param0.categories - Initial array of categories
   * @param {Object} param0.attrs - Additional attributes to set
   */
  constructor({ categories, ...attrs } = {}) {
    this.#items = new TrackedArray(categories || []);

    // assign all the other properties
    Object.keys(attrs).forEach((key) => {
      this[key] = attrs[key];
    });

    const self = this;
    const ownKeys = Object.getOwnPropertyNames(self.constructor.prototype);

    this.#proxy = new Proxy(this.#items, {
      get(target, prop) {
        if (ownKeys.includes(prop)) {
          return self[prop];
        }

        return Reflect.get(target, prop);
      },
      set(target, prop, value) {
        if (ownKeys.includes(prop)) {
          self[prop] = value;
          return true;
        }

        return Reflect.set(target, prop, value);
      },
      has(target, prop) {
        return ownKeys.includes(prop) || prop in target;
      },
      getPrototypeOf() {
        return self.constructor.prototype;
      },
    });

    return this.#proxy;
  }

  /**
   * @returns {Proxy} The proxied content for compatibility
   * @deprecated use the category list instance instead
   */
  get categories() {
    deprecated(
      "Using `CategoryList.categories` property directly is deprecated. Access the item directly from the CategoryList instance instead.",
      { id: "discourse.category-list.legacy-properties" }
    );
    return this.#proxy;
  }

  /**
   * @returns {Proxy} The proxied content for compatibility
   * @deprecated use the category list instance instead
   */
  get content() {
    deprecated(
      "Using `CategoryList.content` property directly is deprecated. Access the item directly from the CategoryList instance instead.",
      { id: "discourse.category-list.legacy-properties" }
    );
    return this.#proxy;
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
      );

      if (!newItems.length) {
        this.fetchedLastPage = true;
      } else {
        newItems.forEach((c) => this.push(c));
      }
    } finally {
      this.isLoading = false;
    }
  }
}
