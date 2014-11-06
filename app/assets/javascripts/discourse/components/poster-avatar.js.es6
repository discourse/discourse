export default Ember.Component.extend({
  tagName: 'a',
  attributeBindings: ['href','data-user-card'],
  classNames: ['trigger-user-card'],
  href: Em.computed.oneWay('post.usernameUrl'),
  "data-user-card": Em.computed.oneWay('post.username'),

  render: function(buffer) {
    var avatar = Handlebars.helpers.avatar(this.get('post'), {hash: {imageSize: 'large'}});
    buffer.push(avatar);
  }
});
