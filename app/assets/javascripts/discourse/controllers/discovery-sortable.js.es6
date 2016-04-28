// Just add query params here to have them automatically passed to topic list filters.
export var queryParams = {
  order: { replace: true, refreshModel: true },
  ascending: { replace: true, refreshModel: true },
  status: { replace: true, refreshModel: true },
  state: { replace: true, refreshModel: true },
  search: { replace: true, refreshModel: true },
  max_posts: { replace: true, refreshModel: true },
  q: { replace: true, refreshModel: true }
};

// Basic controller options
var controllerOpts = {
  needs: ['discovery/topics'],
  queryParams: Object.keys(queryParams),
};

// Aliases for the values
controllerOpts.queryParams.forEach(p => controllerOpts[p] = Em.computed.alias(`controllers.discovery/topics.${p}`));

export default Ember.Controller.extend(controllerOpts);
