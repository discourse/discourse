export default Ember.Component.extend({
  classNames: ['user-small'],

  userPath: Discourse.computed.url('username', '/users/%@'),

  name: function() {
    const name = this.get('user.name');
    if (name && this.get('user.username') !== name) {
      return name;
    }
  }.property('user.name')

});
