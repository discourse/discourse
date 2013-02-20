(function() {

  window.Discourse.ExcerptCategoryView = Ember.View.extend({
    editCategory: function() {
      var cat, _ref;
      this.get('parentView').close();
      /* We create an attribute, id, with the old name so we can rename it.
      */

      cat = this.get('category');
      cat.set('id', cat.get('slug'));
      if (_ref = this.get('controller.controllers.modal')) {
        _ref.showView(Discourse.EditCategoryView.create({
          category: cat
        }));
      }
      return false;
    },
    deleteCategory: function() {
      var _this = this;
      this.get('parentView').close();
      bootbox.confirm(Em.String.i18n("category.delete_confirm"), function(result) {
        if (result) {
          return _this.get('category')["delete"](function() {
            return Discourse.get('appController').reloadSession(function() {
              return Discourse.get('router').route("/categories");
            });
          });
        }
      });
      return false;
    },
    didInsertElement: function() {
      return this.set('category', Discourse.Category.create({
        name: this.get('name'),
        color: this.get('color'),
        slug: this.get('slug'),
        excerpt: this.get('excerpt'),
        topic_url: this.get('topic_url')
      }));
    }
  });

}).call(this);
