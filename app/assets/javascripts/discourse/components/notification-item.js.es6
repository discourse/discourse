export default Ember.Component.extend({
  tagName: 'li',
  classNameBindings: ['notification.read', 'notification.is_warning'],

  _markRead: function(){
    var self = this;
    this.$('a').click(function(){
      self.set('notification.read', true);
      return true;
    });
  }.on('didInsertElement'),

  render: function(buffer) {
    var notification = this.get('notification'),
        text = I18n.t(this.get('scope'), Em.getProperties(notification, 'description', 'username'));

    var url = notification.get('url');
    if (url) {
      buffer.push('<a href="' + notification.get('url') + '">' + text + '</a>');
    } else {
      buffer.push(text);
    }
  }
});
