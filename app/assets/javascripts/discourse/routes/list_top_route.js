Discourse.ListTopRoute = Discourse.Route.extend({

  model: function() {
    return Discourse.TopList.find();
  },

  activate: function() {
    this._super();
    // will mark the "top" navigation item as selected
    this.controllerFor('list').setProperties({
      filterMode: 'top',
      category: null
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
