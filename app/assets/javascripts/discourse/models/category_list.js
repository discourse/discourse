/**
  A data model for containing a list of categories

  @class CategoryList
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.CategoryList = Ember.ArrayProxy.extend({

  init: function() {
    this.content = [];
    this._super();
  },

  moveCategory: function(categoryId, position){
    Discourse.ajax("/category/" + categoryId + "/move", {
      type: 'POST',
      data: {position: position}
    });
  }
});

Discourse.CategoryList.reopenClass({

  categoriesFrom: function(result) {
    var categories = Discourse.CategoryList.create();
    var users = Discourse.Model.extractByKey(result.featured_users, Discourse.User);


    _.each(result.category_list.categories,function(c) {
      if (c.featured_user_ids) {
        c.featured_users = _.map(c.featured_user_ids,function(u) {
          return users[u];
        });
      }
      if (c.topics) {
        c.topics = _.map(c.topics,function(t) {
          return Discourse.Topic.create(t);
        });
      }

      if (c.is_uncategorized) {
        var uncategorized = Discourse.Category.uncategorizedInstance();
        uncategorized.setProperties({
          topics: c.topics,
          featured_users: c.featured_users,
          topics_week: c.topics_week,
          topics_month: c.topics_month,
          topics_year: c.topics_year
        });
        categories.pushObject(uncategorized);
      } else {
        categories.pushObject(Discourse.Category.create(c));
      }
    });
    return categories;
  },

  list: function(filter) {
    var self = this;
    var finder = null;
    if (filter === 'categories') {
      finder = PreloadStore.getAndRemove("categories_list", function() {
        return Discourse.ajax("/categories.json");
      });
    } else {
      finder = Discourse.ajax("/" + filter + ".json");
    }

    return finder.then(function(result) {
      var categoryList = Discourse.TopicList.create();
      categoryList.setProperties({
        can_create_category: result.category_list.can_create_category,
        can_create_topic: result.category_list.can_create_topic,
        categories: self.categoriesFrom(result),
        draft_key: result.category_list.draft_key,
        draft_sequence: result.category_list.draft_sequence
      });
      return categoryList;
    });
  }

});


