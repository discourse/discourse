export default Ember.ArrayController.extend({
  actions: {
    goToGithub: function() {
      window.open('https://github.com/discourse/discourse');
    }
  }
});
