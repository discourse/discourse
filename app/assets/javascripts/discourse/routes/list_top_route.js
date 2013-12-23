Discourse.ListTopRoute = Discourse.Route.extend({

  activate: function() {
    // will mark the "top" navigation item as selected
    this.controllerFor('list').setProperties({
      filterMode: 'top',
      category: null
    });
  },

  model: function() {
    return Discourse.TopList.find();
  },

  renderTemplate: function() {
    this.render('top', { into: 'list', outlet: 'listView' });
  },

  deactivate: function() {
    // Clear any filters when we leave the route
    Discourse.URL.set('queryParams', null);
  }

});
