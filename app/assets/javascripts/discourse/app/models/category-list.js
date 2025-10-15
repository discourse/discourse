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

export default class CategoryList extends TrackedArray {
  static categoriesFrom(store, result, parentCategory = null) {
    // Find the period that is most relevant
    const statPeriod =
      ["week", "month"].find(
        (period) =>
          result.category_list.categories.filter(
            (c) => c[`topics_${period}`] > 0
          ).length >=
          result.category_list.categories.length * 0.66
      ) || "all";

    // Update global category list to make sure that `findById` works as
    // expected later
    result.category_list.categories.forEach((c) =>
      Site.current().updateCategory(c)
    );

    const categories = CategoryList.create({ store });
    result.category_list.categories.forEach((c) => {
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
    if (c.topics) {
      c.topics = c.topics.map((t) => Topic.create(t));
    }

    const stat = c[`topics_${statPeriod}`];
    if ((statPeriod === "week" || statPeriod === "month") && stat > 0) {
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

  static listForParent(store, category) {
    deprecated(
      "The listForParent method of CategoryList is deprecated. Use list instead",
      { id: "discourse.category-list.listForParent" }
    );

    return CategoryList.list(store, category);
  }

  static async list(store, parentCategory = null) {
    const result = await PreloadStore.getAndRemove(
      "categories_list",
      async () => {
        const data = {};
        if (parentCategory) {
          data.parent_category_id = parentCategory?.id;
        }
        return await ajax("/categories.json", { data });
      }
    );

    return CategoryList.create({
      store,
      categories: this.categoriesFrom(store, result, parentCategory),
      parentCategory,
      can_create_category: result.category_list.can_create_category,
      can_create_topic: result.category_list.can_create_topic,
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

  constructor({ categories, attrs } = {}) {
    super(categories || []);

    this.page = 1;
    this.fetchedLastPage = false;

    Object.keys(attrs).forEach((key) => {
      this[key] = attrs[key];
    });
  }

  // for compatibility with the old category list based on ArrayProxy
  get categories() {
    // TODO deprecate this
    return this;
  }

  // for compatibility with the old category list based on ArrayProxy
  get content() {
    // TODO deprecate this
    return this;
  }

  @bind
  async loadMore() {
    if (this.isLoading || this.fetchedLastPage) {
      return;
    }

    this.isLoading = true;

    const data = { page: this.page + 1 };
    if (this.parentCategory) {
      data.parent_category_id = this.parentCategory.id;
    }
    const result = await ajax("/categories.json", { data });

    this.page = data.page;
    if (result.category_list.categories.length === 0) {
      this.fetchedLastPage = true;
    }
    this.isLoading = false;

    CategoryList.categoriesFrom(
      this.store,
      result,
      this.parentCategory
    ).forEach((c) => this.push(c));
  }
}
