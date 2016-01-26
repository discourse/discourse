export default Ember.Component.extend({
  tagName: 'span',

  showGrantCount: function() {
    return this.get('count') && this.get('count') > 1;
  }.property('count'),

  badgeUrl: function(){
    // NOTE: I tried using a link-to helper here but the queryParams mean it fails
    var username = this.get('user.username_lower') || '';
    username = username !== '' ? "?username=" + username : '';
    return this.get('badge.url') + username;
  }.property("badge", "user")

});
