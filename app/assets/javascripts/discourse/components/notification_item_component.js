Discourse.NotificationItemComponent = Ember.Component.extend({
  tagName: 'span',
  didInsertElement: function(){
    var self = this;
    this.$('a').click(function(){
      self.set('model.read', true);
      self.rerender();
      return true;
    });
  }
});
