import { tracked } from "@glimmer/tracking";
import EmberObject, { computed, get } from "@ember/object";
import { alias, sort } from "@ember/object/computed";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import PreloadStore from "discourse/lib/preload-store";
import Singleton from "discourse/mixins/singleton";
import Archetype from "discourse/models/archetype";
import Category from "discourse/models/category";
import PostActionType from "discourse/models/post-action-type";
import RestModel from "discourse/models/rest";
import TrustLevel from "discourse/models/trust-level";
import deprecated from "discourse-common/lib/deprecated";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import discourseComputed from "discourse-common/utils/decorators";

export default class Site extends RestModel.extend().reopenClass(Singleton) {
  static createCurrent() {
    const store = getOwnerWithFallback(this).lookup("service:store");
    const siteAttributes = PreloadStore.get("site");
    siteAttributes["isReadOnly"] = PreloadStore.get("isReadOnly");
    siteAttributes["isStaffWritesOnly"] = PreloadStore.get("isStaffWritesOnly");
    return store.createRecord("site", siteAttributes);
  }

  static create() {
    const result = super.create.apply(this, arguments);

    if (result.categories) {
      result.categories = result.categories.map((c) => {
        return result.store.createRecord("category", c);
      });
    }

    if (result.trust_levels) {
      result.trustLevels = Object.entries(result.trust_levels).map(
        ([key, id]) => {
          return new TrustLevel(id, key);
        }
      );
      delete result.trust_levels;
    }

    if (result.post_action_types) {
      result.postActionByIdLookup = EmberObject.create();
      result.post_action_types = result.post_action_types.map((p) => {
        const actionType = PostActionType.create(p);
        result.postActionByIdLookup.set("action" + p.id, actionType);
        return actionType;
      });
    }

    if (result.topic_flag_types) {
      result.topicFlagByIdLookup = EmberObject.create();
      result.topic_flag_types = result.topic_flag_types.map((p) => {
        const actionType = PostActionType.create(p);
        result.topicFlagByIdLookup.set("action" + p.id, actionType);
        return actionType;
      });
    }

    if (result.archetypes) {
      result.archetypes = result.archetypes.map((a) => {
        a.site = result;
        return Archetype.create(a);
      });
    }

    if (result.user_fields) {
      result.user_fields = result.user_fields.map((uf) =>
        EmberObject.create(uf)
      );
    }

    return result;
  }

  @tracked categories;

  @alias("is_readonly") isReadOnly;

  @sort("categories", "topicCountDesc") categoriesByCount;

  init() {
    super.init(...arguments);

    this.topicCountDesc = ["topic_count:desc"];
    this.categories = this.categories || [];
  }

  @computed("categories.[]")
  get categoriesById() {
    const map = new Map();
    this.categories.forEach((c) => map.set(c.id, c));
    return map;
  }

  @discourseComputed("notification_types")
  notificationLookup(notificationTypes) {
    const result = [];
    Object.keys(notificationTypes).forEach(
      (k) => (result[notificationTypes[k]] = k)
    );
    return result;
  }

  @discourseComputed("post_action_types.[]")
  flagTypes() {
    const postActionTypes = this.post_action_types;
    if (!postActionTypes) {
      return [];
    }
    return postActionTypes.filterBy("is_flag", true);
  }

  collectUserFields(fields) {
    fields = fields || {};

    let siteFields = this.user_fields;

    if (!isEmpty(siteFields)) {
      return siteFields.map((f) => {
        let value = fields ? fields[f.id.toString()] : null;
        value = value || htmlSafe("&mdash;");
        return { name: f.name, value };
      });
    }
    return [];
  }

  // Sort subcategories under parents
  @discourseComputed("categoriesByCount", "categories.[]")
  sortedCategories(categories) {
    return Category.sortCategories(categories);
  }

  // Returns it in the correct order, by setting
  @discourseComputed("categories.[]")
  categoriesList(categories) {
    return this.siteSettings.fixed_category_positions
      ? categories
      : this.sortedCategories;
  }

  @discourseComputed("categories.[]", "categories.@each.notification_level")
  trackedCategoriesList(categories) {
    const trackedCategories = [];

    for (const category of categories) {
      if (category.isTracked) {
        if (
          this.siteSettings.allow_uncategorized_topics ||
          !category.isUncategorizedCategory
        ) {
          trackedCategories.push(category);
        }
      }
    }

    return trackedCategories;
  }

  postActionTypeById(id) {
    return this.get("postActionByIdLookup.action" + id);
  }

  topicFlagTypeById(id) {
    return this.get("topicFlagByIdLookup.action" + id);
  }

  removeCategory(id) {
    const categories = this.categories;
    const existingCategory = categories.findBy("id", id);
    if (existingCategory) {
      categories.removeObject(existingCategory);
    }
  }

  updateCategory(newCategory) {
    const categories = this.categories;
    const categoryId = get(newCategory, "id");
    const existingCategory = categories.findBy("id", categoryId);

    // Don't update null permissions
    if (newCategory.permission === null) {
      delete newCategory.permission;
    }

    if (existingCategory) {
      existingCategory.setProperties(newCategory);
      return existingCategory;
    } else {
      // TODO insert in right order?
      newCategory = this.store.createRecord("category", newCategory);
      categories.pushObject(newCategory);
      return newCategory;
    }
  }
}

if (typeof Discourse !== "undefined") {
  let warned = false;
  // eslint-disable-next-line no-undef
  Object.defineProperty(Discourse, "Site", {
    get() {
      if (!warned) {
        deprecated("Import the Site class instead of using Discourse.Site", {
          since: "2.4.0",
          id: "discourse.globals.site",
        });
        warned = true;
      }
      return Site;
    },
  });
}
