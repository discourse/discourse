// Create the topic list filtered routes

(function() {

  window.Discourse.FilteredListRoute = Discourse.Route.extend({
    exit: function() {
      var listController;
      this._super();
      listController = this.controllerFor('list');
      listController.set('canCreateTopic', false);
      return listController.set('filterMode', '');
    },
    renderTemplate: function() {
      return this.render('listTopics', {
        into: 'list',
        outlet: 'listView',
        controller: 'listTopics'
      });
    },
    setupController: function() {
      var listController, listTopicsController, _ref,
        _this = this;
      listController = this.controllerFor('list');
      listTopicsController = this.controllerFor('listTopics');
      listController.set('filterMode', this.filter);
      if (_ref = listTopicsController.get('content')) {
        _ref.set('loaded', false);
      }
      return listController.load(this.filter).then(function(topicList) {
        listController.set('category', null);
        listController.set('canCreateTopic', topicList.get('can_create_topic'));
        return listTopicsController.set('content', topicList);
      });
    }
  });

  Discourse.ListController.filters.each(function(filter) {
    Discourse["List" + (filter.capitalize()) + "Route"] = Discourse.FilteredListRoute.extend({
      filter: filter
    });
  });

}).call(this);
