export default Ember.Controller.extend({
  me: Discourse.computed.propertyEqual('model.user.id', 'currentUser.id')
});
