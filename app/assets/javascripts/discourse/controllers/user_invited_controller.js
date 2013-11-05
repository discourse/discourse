/**
  This controller handles actions related to a user's invitations

  @class UserInvitedController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
Discourse.UserInvitedController = Ember.ArrayController.extend({

  _searchTermChanged: Discourse.debounce(function() {
    var self = this;
    Discourse.Invite.findInvitedBy(self.get('user'), this.get('searchTerm')).then(function (invites) {
      self.set('model', invites);
    });
  }, 250).observes('searchTerm'),

  maxInvites: function() {
    return Discourse.SiteSettings.invites_shown;
  }.property(),

  showSearch: function() {
    if (Em.isNone(this.get('searchTerm')) && this.get('model.length') === 0) { return false; }
    return true;
  }.property('searchTerm', 'model.length'),

  truncated: function() {
    return this.get('model.length') === Discourse.SiteSettings.invites_shown;
  }.property('model.length'),

  actions: {
    rescind: function(invite) {
      invite.rescind();
      return false;
    }
  }

});


