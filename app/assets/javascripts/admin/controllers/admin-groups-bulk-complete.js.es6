export default Ember.Controller.extend({
  adminGroupsBulk: Ember.inject.controller(),
  bulkAddResponse: Ember.computed.alias('adminGroupsBulk.bulkAddResponse')
});
