import { tracked } from "@glimmer/tracking";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";
import { number } from "discourse/lib/formatter";
import PreloadStore from "discourse/lib/preload-store";
import Site from "discourse/models/site";
import Topic from "discourse/models/topic";
import { i18n } from "discourse-i18n";

const STAT_PERIODS = ["week", "month"];

export default class CategoryList {
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

  static _buildCategoryResult(c, statPeriod) {
    if (c.topics?.length) {
      c.topics = c.topics.map((t) => Topic.create(t));
    }

    const stat = c[`topics_${statPeriod}`];
    const isTimedPeriod = statPeriod === "week" || statPeriod === "month";
    if (isTimedPeriod && stat > 0) {
      const unit = i18n(`categories.topic_stat_unit.${statPeriod}`);

      c.stat = i18n("categories.topic_stat", {
        count: stat, // only used to correctly pluralize the string
        number: `<span class="value">${number(stat)}</span>`,
        unit: `<span class="unit">${unit}</span>`,
      });

      c.statTitle = i18n(`categories.topic_stat_sentence_${statPeriod}`, {
        count: stat,
      });

      c.pickAll = false;
    } else {
      c.stat = `<span class="value">${number(c.topics_all_time)}</span>`;
      c.statTitle = i18n("categories.topic_sentence", {
        count: c.topics_all_time,
      });
      c.pickAll = true;
    }

    if (Site.current().mobileView) {
      c.statTotal = i18n("categories.topic_stat_all_time", {
        count: c.topics_all_time,
        number: `<span class="value">${number(c.topics_all_time)}</span>`,
      });
    }

    const record = Site.current().updateCategory(c);
    record.setupGroupsAndPermissions();
    return record;
  }

  static listForParent(store, parentCategory) {
    deprecated(
      "The listForParent method of CategoryList is deprecated. Use list instead",
      { id: "discourse.category-list.listForParent" }
    );

    return CategoryList.list(store, parentCategory);
  }

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

  static create(attrs) {
    return new CategoryList(attrs);
  }

  @tracked can_create_category;
  @tracked can_create_topic;
  @tracked fetchedLastPage = false;
  @tracked isLoading = false;
  @tracked page = 1;
  @tracked parentCategory;

  #content;
  #proxy;

  constructor({ categories, ...attrs } = {}) {
    this.#content = new TrackedArray(categories || []);

    // assign all the other properties
    Object.keys(attrs).forEach((key) => {
      this[key] = attrs[key];
    });

    const self = this;
    const ownKeys = Object.getOwnPropertyNames(self.constructor.prototype);

    this.#proxy = new Proxy(this.#content, {
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

  // for compatibility with the old category list based on ArrayProxy
  get categories() {
    // TODO deprecate this
    return this.#proxy;
  }

  // for compatibility with the old category list based on ArrayProxy
  get content() {
    // TODO deprecate this
    return this.#proxy;
  }

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
