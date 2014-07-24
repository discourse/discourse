/**
  This controller is for the widget that shows the commits to the discourse repo.

  @class AdminGithubCommitsController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
export default Ember.ArrayController.extend({
  goToGithub: function() {
    window.open('https://github.com/discourse/discourse');
  }
});
