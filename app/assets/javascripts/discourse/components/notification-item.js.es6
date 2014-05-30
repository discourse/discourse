export default Ember.Component.extend({
  tagName: 'li',
  classNameBindings: ['notification.read'],

  _markRead: function(){
    var self = this;
    this.$('a').click(function(){
      self.set('notification.read', true);
      return true;
    });
  }.on('didInsertElement'),

  render: function(buffer) {
    var notification = this.get('notification'),
        text = I18n.t(this.get('scope'), Em.getProperties(notification, 'link', 'username'));
    buffer.push('<span>' + text + '</span>');
  }
});
