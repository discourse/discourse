export default Ember.Component.extend({
  classNames: ['user-small'],

  name: function() {
    const name = this.get('user.name');
    if (name && this.get('user.username') !== name) {
      return name;
    }
  }.property('user.name')

});
