import { renderAvatar } from 'discourse/helpers/user-avatar';

export default Ember.View.extend({
  tagName: 'a',
  attributeBindings: ['href'],
  classNameBindings: ['content.extras'],

  user: Em.computed.alias('content.user'),
  href: Em.computed.alias('user.path'),

  click: function(e) {
    var user = this.get('user');
    this.appEvents.trigger('poster:expand', $(e.target));
    this.get('controller').send('expandUser', user);
    return false;
  },

  render: function(buffer) {
    var av = renderAvatar(this.get('content'), {usernamePath: 'user.username', imageSize: 'small'});
    buffer.push(av);
  }
});
