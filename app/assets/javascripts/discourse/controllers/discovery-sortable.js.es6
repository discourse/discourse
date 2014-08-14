import DiscourseController from 'discourse/controllers/controller';

// Just add query params here to have them automatically passed to topic list filters.
export var queryParams = {
  order: { replace: true },
  ascending: { replace: true },
  status: { replace: true },
  state: { replace: true },
  search: { replace: true },
  max_posts: { replace: true }
};

// Basic controller options
var controllerOpts = {
  needs: ['discovery/topics'],
  queryParams: Ember.keys(queryParams)
};

// Aliases for the values
controllerOpts.queryParams.forEach(function(p) {
  controllerOpts[p] = Em.computed.alias('controllers.discovery/topics.' + p);
});

export default DiscourseController.extend(controllerOpts);
