import ObjectController from 'discourse/controllers/object';

/**
  Lists of topics on a user's page.

  @class UserTopicsListController
  @extends ObjectController
  @namespace Discourse
  @module Discourse
**/
export default ObjectController.extend({
  hideCategory: false,
  showParticipants: false,

  actions: {
    loadMore: function() {
      this.get('model').loadMore();
    }
  }

});
