import computed from "ember-addons/ember-computed-decorators";
import Archetype from "discourse/models/archetype";
import PostActionType from "discourse/models/post-action-type";
import Singleton from "discourse/mixins/singleton";
import RestModel from "discourse/models/rest";
import PreloadStore from "preload-store";

const Site = RestModel.extend({
  isReadOnly: Em.computed.alias("is_readonly"),

  @computed("notification_types")
  notificationLookup(notificationTypes) {
    const result = [];
    _.each(notificationTypes, (v, k) => (result[v] = k));
    return result;
  },

  @computed("post_action_types.[]")
  flagTypes() {
    const postActionTypes = this.get("post_action_types");
    if (!postActionTypes) return [];
    return postActionTypes.filterBy("is_flag", true);
  },

  topicCountDesc: ["topic_count:desc"],
  categoriesByCount: Ember.computed.sort("categories", "topicCountDesc"),

  // Sort subcategories under parents
  @computed("categoriesByCount", "categories.[]")
  sortedCategories(cats) {
    const result = [],
      remaining = {};

    cats.forEach(c => {
      const parentCategoryId = parseInt(c.get("parent_category_id"), 10);
      if (!parentCategoryId) {
        result.pushObject(c);
      } else {
        remaining[parentCategoryId] = remaining[parentCategoryId] || [];
        remaining[parentCategoryId].pushObject(c);
      }
    });

    Object.keys(remaining).forEach(parentCategoryId => {
      const category = result.findBy("id", parseInt(parentCategoryId, 10)),
        index = result.indexOf(category);

      if (index !== -1) {
        result.replace(index + 1, 0, remaining[parentCategoryId]);
      }
    });

    return result;
  },

  @computed
  baseUri() {
    return Discourse.baseUri;
  },

  // Returns it in the correct order, by setting
  @computed
  categoriesList() {
    return this.siteSettings.fixed_category_positions
      ? this.get("categories")
      : this.get("sortedCategories");
  },

  postActionTypeById(id) {
    return this.get("postActionByIdLookup.action" + id);
  },

  topicFlagTypeById(id) {
    return this.get("topicFlagByIdLookup.action" + id);
  },

  removeCategory(id) {
    const categories = this.get("categories");
    const existingCategory = categories.findBy("id", id);
    if (existingCategory) {
      categories.removeObject(existingCategory);
      delete this.get("categoriesById").categoryId;
    }
  },

  updateCategory(newCategory) {
    const categories = this.get("categories");
    const categoryId = Em.get(newCategory, "id");
    const existingCategory = categories.findBy("id", categoryId);

    // Don't update null permissions
    if (newCategory.permission === null) {
      delete newCategory.permission;
    }

    if (existingCategory) {
      existingCategory.setProperties(newCategory);
    } else {
      // TODO insert in right order?
      newCategory = this.store.createRecord("category", newCategory);
      categories.pushObject(newCategory);
      this.get("categoriesById")[categoryId] = newCategory;
    }
  }
});

Site.reopenClass(Singleton, {
  // The current singleton will retrieve its attributes from the `PreloadStore`.
  createCurrent() {
    const store = Discourse.__container__.lookup("service:store");
    return store.createRecord("site", PreloadStore.get("site"));
  },

  create() {
    const result = this._super.apply(this, arguments);
    const store = result.store;

    if (result.categories) {
      result.categoriesById = {};
      result.categories = _.map(
        result.categories,
        c => (result.categoriesById[c.id] = store.createRecord("category", c))
      );

      // Associate the categories with their parents
      result.categories.forEach(c => {
        if (c.get("parent_category_id")) {
          c.set(
            "parentCategory",
            result.categoriesById[c.get("parent_category_id")]
          );
        }
      });
    }

    if (result.trust_levels) {
      result.trustLevels = result.trust_levels.map(tl =>
        Discourse.TrustLevel.create(tl)
      );
      delete result.trust_levels;
    }

    if (result.post_action_types) {
      result.postActionByIdLookup = Em.Object.create();
      result.post_action_types = _.map(result.post_action_types, p => {
        const actionType = PostActionType.create(p);
        result.postActionByIdLookup.set("action" + p.id, actionType);
        return actionType;
      });
    }

    if (result.topic_flag_types) {
      result.topicFlagByIdLookup = Em.Object.create();
      result.topic_flag_types = _.map(result.topic_flag_types, p => {
        const actionType = PostActionType.create(p);
        result.topicFlagByIdLookup.set("action" + p.id, actionType);
        return actionType;
      });
    }

    if (result.archetypes) {
      result.archetypes = _.map(result.archetypes, a => {
        a.site = result;
        return Archetype.create(a);
      });
    }

    if (result.user_fields) {
      result.user_fields = result.user_fields.map(uf =>
        Ember.Object.create(uf)
      );
    }

    return result;
  }
});

export default Site;
