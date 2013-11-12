/**
  Lists of topics on a user's page.

  @class UserTopicsListController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.UserTopicsListController = Discourse.ObjectController.extend({

  actions: {
    loadMore: function() {
      this.get('model').loadMore();
    }
  }

});
