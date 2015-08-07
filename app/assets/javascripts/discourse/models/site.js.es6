import Archetype from 'discourse/models/archetype';
import PostActionType from 'discourse/models/post-action-type';
import Singleton from 'discourse/mixins/singleton';

const Site = Discourse.Model.extend({

  isReadOnly: Em.computed.alias('is_readonly'),

  notificationLookup: function() {
    const result = [];
    _.each(this.get('notification_types'), function(v,k) {
      result[v] = k;
    });
    return result;
  }.property('notification_types'),

  flagTypes: function() {
    const postActionTypes = this.get('post_action_types');
    if (!postActionTypes) return [];
    return postActionTypes.filterProperty('is_flag', true);
  }.property('post_action_types.@each'),

  topicCountDesc: ['topic_count:desc'],
  categoriesByCount: Ember.computed.sort('categories', 'topicCountDesc'),

  // Sort subcategories under parents
  sortedCategories: function() {
    const cats = this.get('categoriesByCount'),
        result = [],
        remaining = {};

    cats.forEach(function(c) {
      const parentCategoryId = parseInt(c.get('parent_category_id'), 10);
      if (!parentCategoryId) {
        result.pushObject(c);
      } else {
        remaining[parentCategoryId] = remaining[parentCategoryId] || [];
        remaining[parentCategoryId].pushObject(c);
      }
    });

    Ember.keys(remaining).forEach(function(parentCategoryId) {
      const category = result.findBy('id', parseInt(parentCategoryId, 10)),
          index = result.indexOf(category);

      if (index !== -1) {
        result.replace(index+1, 0, remaining[parentCategoryId]);
      }
    });

    return result;
  }.property("categories.@each"),

  postActionTypeById(id) {
    return this.get("postActionByIdLookup.action" + id);
  },

  topicFlagTypeById(id) {
    return this.get("topicFlagByIdLookup.action" + id);
  },

  removeCategory(id) {
    const categories = this.get('categories');
    const existingCategory = categories.findProperty('id', id);
    if (existingCategory) {
      categories.removeObject(existingCategory);
      delete this.get('categoriesById').categoryId;
    }
  },

  updateCategory(newCategory) {
    const categories = this.get('categories');
    const categoryId = Em.get(newCategory, 'id');
    const existingCategory = categories.findProperty('id', categoryId);

    // Don't update null permissions
    if (newCategory.permission === null) { delete newCategory.permission; }

    if (existingCategory) {
      existingCategory.setProperties(newCategory);
    } else {
      // TODO insert in right order?
      newCategory = Discourse.Category.create(newCategory);
      categories.pushObject(newCategory);
      this.get('categoriesById')[categoryId] = newCategory;
    }
  }
});

Site.reopenClass(Singleton, {

  // The current singleton will retrieve its attributes from the `PreloadStore`.
  createCurrent() {
    return Site.create(PreloadStore.get('site'));
  },

  create() {
    const result = this._super.apply(this, arguments);

    if (result.categories) {
      result.categoriesById = {};
      result.categories = _.map(result.categories, function(c) {
        return result.categoriesById[c.id] = Discourse.Category.create(c);
      });

      // Associate the categories with their parents
      result.categories.forEach(function (c) {
        if (c.get('parent_category_id')) {
          c.set('parentCategory', result.categoriesById[c.get('parent_category_id')]);
        }
      });
    }

    if (result.trust_levels) {
      result.trustLevels = result.trust_levels.map(function (tl) {
        return Discourse.TrustLevel.create(tl);
      });

      delete result.trust_levels;
    }

    if (result.post_action_types) {
      result.postActionByIdLookup = Em.Object.create();
      result.post_action_types = _.map(result.post_action_types,function(p) {
        const actionType = PostActionType.create(p);
        result.postActionByIdLookup.set("action" + p.id, actionType);
        return actionType;
      });
    }

    if (result.topic_flag_types) {
      result.topicFlagByIdLookup = Em.Object.create();
      result.topic_flag_types = _.map(result.topic_flag_types,function(p) {
        const actionType = PostActionType.create(p);
        result.topicFlagByIdLookup.set("action" + p.id, actionType);
        return actionType;
      });
    }

    if (result.archetypes) {
      result.archetypes = _.map(result.archetypes,function(a) {
        a.site = result;
        return Archetype.create(a);
      });
    }

    if (result.user_fields) {
      result.user_fields = result.user_fields.map(function(uf) {
        return Ember.Object.create(uf);
      });
    }

    return result;
  }
});

export default Site;
