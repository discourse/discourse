(function() {

  window.Discourse.CategoryList = Discourse.Model.extend({});

  window.Discourse.CategoryList.reopenClass({
    categoriesFrom: function(result) {
      var categories, users;
      categories = Em.A();
      users = this.extractByKey(result.featured_users, Discourse.User);
      result.category_list.categories.each(function(c) {
        if (c.featured_user_ids) {
          c.featured_users = c.featured_user_ids.map(function(u) {
            return users[u];
          });
        }
        if (c.topics) {
          c.topics = c.topics.map(function(t) {
            return Discourse.Topic.create(t);
          });
        }
        return categories.pushObject(Discourse.Category.create(c));
      });
      return categories;
    },
    list: function(filter) {
      var promise,
        _this = this;
      promise = new RSVP.Promise();
      jQuery.getJSON("/" + filter + ".json").then(function(result) {
        var categoryList;
        categoryList = Discourse.TopicList.create();
        categoryList.set('can_create_category', result.category_list.can_create_category);
        categoryList.set('categories', _this.categoriesFrom(result));
        categoryList.set('loaded', true);
        return promise.resolve(categoryList);
      });
      return promise;
    }
  });

}).call(this);
