(function() {

  window.Discourse.ListCategoriesRoute = Discourse.Route.extend({
    exit: function() {
      this._super();
      return this.controllerFor('list').set('canCreateCategory', false);
    },
    setupController: function(controller) {
      var listController,
        _this = this;
      listController = this.controllerFor('list');
      listController.set('filterMode', 'categories');
      return listController.load('categories').then(function(categoryList) {
        _this.render('listCategories', {
          into: 'list',
          outlet: 'listView',
          controller: 'listCategories'
        });
        listController.set('canCreateCategory', categoryList.get('can_create_category'));
        listController.set('category', null);
        return _this.controllerFor('listCategories').set('content', categoryList);
      });
    }
  });

}).call(this);
