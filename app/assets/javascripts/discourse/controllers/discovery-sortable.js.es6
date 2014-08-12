export default Discourse.Controller.extend({
  needs: ['discovery/topics'],
  queryParams: ['order', 'ascending', 'status', 'state', 'search'],
  order: Em.computed.alias('controllers.discovery/topics.order'),
  ascending: Em.computed.alias('controllers.discovery/topics.ascending'),
  status: Em.computed.alias('controllers.discovery/topics.status'),
  search: Em.computed.alias('controllers.discovery/topics.search')
});
