Discourse.ListTopRoute = Discourse.Route.extend({

  activate: function() {
    this._super();
    // will mark the "top" navigation item as selected
    this.controllerFor('list').setProperties({
      filterMode: 'top',
      category: null
    });
  },

  setupController: function() {
    var topController = this.controllerFor("top");
    Discourse.TopList.find().then(function (result) {
      topController.set("model", result);
    });
  },

  renderTemplate: function() {
    this.render('top', { into: 'list', outlet: 'listView' });
  },

  deactivate: function() {
    this._super();
    // Clear any filters when we leave the route
    Discourse.URL.set('queryParams', null);
  }

});
