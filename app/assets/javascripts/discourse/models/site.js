/**
  A data model representing the site (instance of Discourse)

  @class Site
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.Site = Discourse.Model.extend({

  notificationLookup: function() {
    var result = [];
    _.each(this.get('notification_types'), function(v,k) {
      result[v] = k;
    });
    return result;
  }.property('notification_types'),

  flagTypes: function() {
    var postActionTypes = this.get('post_action_types');
    if (!postActionTypes) return [];
    return postActionTypes.filterProperty('is_flag', true);
  }.property('post_action_types.@each'),

  postActionTypeById: function(id) {
    return this.get("postActionByIdLookup.action" + id);
  },

  updateCategory: function(newCategory) {
    var existingCategory = this.get('categories').findProperty('id', Em.get(newCategory, 'id'));
    if (existingCategory) existingCategory.mergeAttributes(newCategory);
  }
});

Discourse.Site.reopenClass(Discourse.Singleton, {

  /**
    The current singleton will retrieve its attributes from the `PreloadStore`.

    @method createCurrent
    @returns {Discourse.Site} the site
  **/
  createCurrent: function() {
    return Discourse.Site.create(PreloadStore.get('site'));
  },

  create: function() {
    var result = this._super.apply(this, arguments);

    if (result.categories) {
      var byId = {};
      result.categories = _.map(result.categories, function(c) {
        byId[c.id] = Discourse.Category.create(c);
        return byId[c.id];
      });

      // Associate the categories with their parents
      result.categories.forEach(function (c) {
        if (c.get('parent_category_id')) {
          c.set('parentCategory', byId[c.get('parent_category_id')]);
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
        var actionType = Discourse.PostActionType.create(p);
        result.postActionByIdLookup.set("action" + p.id, actionType);
        return actionType;
      });
    }
    if (result.archetypes) {
      result.archetypes = _.map(result.archetypes,function(a) {
        return Discourse.Archetype.create(a);
      });
    }

    return result;
  }
});


