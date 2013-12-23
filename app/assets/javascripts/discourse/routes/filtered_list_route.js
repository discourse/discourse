/**
  A class used to handle filtering routes such as latest, hot, read, etc.

  @class FilteredListRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.FilteredListRoute = Discourse.Route.extend({

  redirect: function() { Discourse.redirectIfLoginRequired(this); },

  deactivate: function() {
    this._super();

    this.controllerFor('list').setProperties({
      canCreateTopic: false,
      filterMode: ''
    });
  },

  renderTemplate: function() {
    this.render('listTopics', {
      into: 'list',
      outlet: 'listView',
      controller: 'listTopics'
    });
  },

  setupController: function() {
    var listController = this.controllerFor('list'),
        listTopicsController = this.controllerFor('listTopics');

    listController.set('filterMode', this.filter);

    var listContent = listTopicsController.get('model');
    if (listContent) {
      listContent.set('loaded', false);
    }

    listController.set('category', null);
    listController.load(this.filter).then(function(topicList) {
      listController.set('canCreateTopic', topicList.get('can_create_topic'));
      listTopicsController.set('model', topicList);
      Discourse.FilteredListRoute.scrollToLastPosition();
    });
  }
});

Discourse.FilteredListRoute.reopenClass({
  scrollToLastPosition: function() {
    var scrollPos = Discourse.Session.currentProp('topicListScrollPosition');
    if (scrollPos) {
      Em.run.next(function() { $('html, body').scrollTop(scrollPos); });
      Discourse.Session.currentProp('topicListScrollPosition', null);
    }
  }
});

Discourse.ListController.filters.forEach(function(filter) {
  Discourse["List" + (filter.capitalize()) + "Route"] = Discourse.FilteredListRoute.extend({ filter: filter });
});
