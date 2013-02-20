(function() {

  Discourse.ListCategoriesController = Ember.ObjectController.extend(Discourse.Presence, {
    needs: ['modal'],
    categoriesEven: (function() {
      if (this.blank('categories')) {
        return Em.A();
      }
      return this.get('categories').filter(function(item, index) {
        return (index % 2) === 0;
      });
    }).property('categories.@each'),
    categoriesOdd: (function() {
      if (this.blank('categories')) {
        return Em.A();
      }
      return this.get('categories').filter(function(item, index) {
        return (index % 2) === 1;
      });
    }).property('categories.@each'),
    editCategory: function(category) {
      this.get('controllers.modal').show(Discourse.EditCategoryView.create({
        category: category
      }));
      return false;
    },
    canEdit: (function() {
      var u;
      u = Discourse.get('currentUser');
      return u && u.admin;
    }).property()
  });

}).call(this);
