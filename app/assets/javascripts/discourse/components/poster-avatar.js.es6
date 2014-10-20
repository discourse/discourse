export default Ember.Component.extend({
  tagName: 'a',
  attributeBindings: ['href'],
  classNames: ['trigger-user-card'],
  href: Em.computed.alias('post.usernameUrl'),

  click: function(e) {
    this.appEvents.trigger('poster:expand', $(e.target));
    this.sendAction('action', this.get('post'));
    return false;
  },

  render: function(buffer) {
    var avatar = Handlebars.helpers.avatar(this.get('post'), {hash: {imageSize: 'large'}});
    buffer.push(avatar);
  }
});
