/**
  Lists of topics on a user's page.

  @class UserTopicsListController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
export default Discourse.ObjectController.extend({
  hideCategory: false,
  showParticipants: false,

  actions: {
    loadMore: function() {
      this.get('model').loadMore();
    }
  }

});
