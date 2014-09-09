import { renderAvatar } from 'discourse/helpers/user-avatar';

export default Ember.View.extend({
  tagName: 'a',
  attributeBindings: ['href', 'data-user-expand'],
  classNameBindings: ['content.extras'],

  user: Em.computed.alias('content.user'),
  href: Em.computed.alias('user.path'),

  'data-user-expand': Em.computed.alias('user.username'),

  render: function(buffer) {
    var av = renderAvatar(this.get('content'), {usernamePath: 'user.username', imageSize: 'small'});
    buffer.push(av);
  }
});
