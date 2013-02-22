/**
  This route displays a user's private messages.

  @class UserPrivateMessagesRoute
  @extends Discourse.RestrictedUserRoute
  @namespace Discourse
  @module Discourse
**/
Discourse.UserPrivateMessagesRoute = Discourse.RestrictedUserRoute.extend({

  renderTemplate: function() {
    this.render({ into: 'user', outlet: 'userOutlet' });
  },

  setupController: function(controller, user) {
    var _this = this;
    user = this.controllerFor('user').get('content');
    controller.set('content', user);
    user.filterStream(Discourse.UserAction.GOT_PRIVATE_MESSAGE);
    Discourse.Draft.get('new_private_message').then(function(data) {
      if (data.draft) {
        _this.controllerFor('composer').open({
          draft: data.draft,
          draftKey: 'new_private_message',
          ignoreIfChanged: true,
          draftSequence: data.draft_sequence
        });
      }
    });
  }

});


