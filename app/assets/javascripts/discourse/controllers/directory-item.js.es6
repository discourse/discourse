import { propertyEqual } from 'discourse/lib/computed';

export default Ember.Controller.extend({
  me: propertyEqual('model.user.id', 'currentUser.id')
});
