import ArrayProxy from "@ember/array/proxy";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";
import { number } from "discourse/lib/formatter";
import PreloadStore from "discourse/lib/preload-store";
import Site from "discourse/models/site";
import Topic from "discourse/models/topic";
import { i18n } from "discourse-i18n";

export default class CategoryList extends ArrayProxy {
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
        categories.pushObject(c);
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

  static list(store, parentCategory = null) {
    return PreloadStore.getAndRemove("categories_list", () => {
      const data = {};
      if (parentCategory) {
        data.parent_category_id = parentCategory?.id;
      }
      return ajax("/categories.json", { data });
    }).then((result) => {
      return CategoryList.create({
        store,
        categories: this.categoriesFrom(store, result, parentCategory),
        parentCategory,
        can_create_category: result.category_list.can_create_category,
        can_create_topic: result.category_list.can_create_topic,
      });
    });
  }

  init() {
    this.set("content", this.categories || []);
    super.init(...arguments);
    this.set("page", 1);
    this.set("fetchedLastPage", false);
  }

  @bind
  async loadMore() {
    if (this.isLoading || this.fetchedLastPage) {
      return;
    }

    this.set("isLoading", true);

    const data = { page: this.page + 1 };
    if (this.parentCategory) {
      data.parent_category_id = this.parentCategory.id;
    }
    const result = await ajax("/categories.json", { data });

    this.set("page", data.page);
    if (result.category_list.categories.length === 0) {
      this.set("fetchedLastPage", true);
    }
    this.set("isLoading", false);

    CategoryList.categoriesFrom(
      this.store,
      result,
      this.parentCategory
    ).forEach((c) => this.categories.pushObject(c));
  }
}
