Discourse.DiscoverySortableController = Discourse.Controller.extend({
  needs: ['discoveryTopics'],
  queryParams: ['order', 'ascending'],
  order: Em.computed.alias('controllers.discoveryTopics.order'),
  ascending: Em.computed.alias('controllers.discoveryTopics.ascending')
});
