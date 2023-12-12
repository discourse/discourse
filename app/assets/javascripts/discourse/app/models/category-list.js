import ArrayProxy from "@ember/array/proxy";
import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { number } from "discourse/lib/formatter";
import PreloadStore from "discourse/lib/preload-store";
import Category from "discourse/models/category";
import Site from "discourse/models/site";
import Topic from "discourse/models/topic";
import { bind } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

const MAX_CATEGORIES_LIMIT = 25;

const CategoryList = ArrayProxy.extend({
  init() {
    this._super(...arguments);
    this.set("content", []);
    this.set("page", 1);
  },

  @bind
  async loadMore() {
    if (this.isLoading || this.lastPage) {
      return;
    }

    this.set("isLoading", true);

    const data = { page: this.page + 1, limit: MAX_CATEGORIES_LIMIT };
    if (this.parentCategory) {
      data.parent_category_id = this.parentCategory.id;
    }
    const result = await ajax("/categories.json", { data });
    this.set("page", data.page);

    result.category_list.categories.forEach((c) => {
      const record = Site.current().updateCategory(c);
      this.categories.pushObject(record);
    });

    this.set("isLoading", false);

    if (result.category_list.categories.length === 0) {
      this.set("lastPage", true);
    }

    const newCategoryList = CategoryList.categoriesFrom(this.store, result);
    this.categories.pushObjects(newCategoryList.categories);
  },
});

CategoryList.reopenClass({
  categoriesFrom(store, result) {
    const categories = CategoryList.create({ store });
    const list = Category.list();

    let statPeriod = "all";
    const minCategories = result.category_list.categories.length * 0.66;

    ["week", "month"].some((period) => {
      const filteredCategories = result.category_list.categories.filter(
        (c) => c[`topics_${period}`] > 0
      );
      if (filteredCategories.length >= minCategories) {
        statPeriod = period;
        return true;
      }
    });

    result.category_list.categories.forEach((c) =>
      categories.pushObject(this._buildCategoryResult(c, list, statPeriod))
    );

    return categories;
  },

  _buildCategoryResult(c, list, statPeriod) {
    if (c.parent_category_id) {
      c.parentCategory = list.findBy("id", c.parent_category_id);
    }

    if (c.subcategory_list) {
      c.subcategories = c.subcategory_list.map((subCategory) =>
        this._buildCategoryResult(subCategory, list, statPeriod)
      );
    } else if (c.subcategory_ids) {
      c.subcategories = c.subcategory_ids.map((scid) =>
        list.findBy("id", parseInt(scid, 10))
      );
    }

    if (c.subcategories) {
      // TODO: Not all subcategory_ids have been loaded
      c.subcategories = c.subcategories?.filter(Boolean);
    }

    if (c.topics) {
      c.topics = c.topics.map((t) => Topic.create(t));
    }

    const stat = c[`topics_${statPeriod}`];

    if ((statPeriod === "week" || statPeriod === "month") && stat > 0) {
      const unit = I18n.t(`categories.topic_stat_unit.${statPeriod}`);

      c.stat = I18n.t("categories.topic_stat", {
        count: stat, // only used to correctly pluralize the string
        number: `<span class="value">${number(stat)}</span>`,
        unit: `<span class="unit">${unit}</span>`,
      });

      c.statTitle = I18n.t(`categories.topic_stat_sentence_${statPeriod}`, {
        count: stat,
      });

      c.pickAll = false;
    } else {
      c.stat = `<span class="value">${number(c.topics_all_time)}</span>`;
      c.statTitle = I18n.t("categories.topic_sentence", {
        count: c.topics_all_time,
      });
      c.pickAll = true;
    }

    if (Site.currentProp("mobileView")) {
      c.statTotal = I18n.t("categories.topic_stat_all_time", {
        count: c.topics_all_time,
        number: `<span class="value">${number(c.topics_all_time)}</span>`,
      });
    }

    const record = Site.current().updateCategory(c);
    record.setupGroupsAndPermissions();
    return record;
  },

  listForParent(store, category) {
    return ajax(
      `/categories.json?parent_category_id=${category.get("id")}`
    ).then((result) => {
      return EmberObject.create({
        store,
        categories: this.categoriesFrom(store, result),
        parentCategory: category,
      });
    });
  },

  list(store) {
    const getCategories = () => ajax("/categories.json");
    return PreloadStore.getAndRemove("categories_list", getCategories).then(
      (result) => {
        return CategoryList.create({
          store,
          categories: this.categoriesFrom(store, result),
          can_create_category: result.category_list.can_create_category,
          can_create_topic: result.category_list.can_create_topic,
        });
      }
    );
  },
});

export default CategoryList;
