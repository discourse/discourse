import { url } from 'discourse/lib/computed';
import computed from 'ember-addons/ember-computed-decorators';

function normalize(name) {
  return name.replace(/[\-\_ \.]/g, '').toLowerCase();
}

export default Ember.Component.extend({
  classNameBindings: [':user-info', 'size'],
  size: 'small',
  userPath: url('user.username', '/users/%@'),

  // TODO: In later ember releases `hasBlock` works without this
  hasBlock: Ember.computed.alias('template'),

  @computed('user.name', 'user.username')
  name(name, username) {
    if (name && normalize(username) !== normalize(name)) {
      return name;
    }
  }

});
