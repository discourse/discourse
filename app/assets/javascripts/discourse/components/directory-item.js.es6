import { propertyEqual } from 'discourse/lib/computed';

export default Ember.Component.extend({
  tagName: 'tr',
  classNameBindings: ['me'],
  me: propertyEqual('item.user.id', 'currentUser.id')
});
