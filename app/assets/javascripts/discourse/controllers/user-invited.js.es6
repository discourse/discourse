/**
  This controller handles actions related to a user's invitations

  @class UserInvitedController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
export default Ember.ObjectController.extend({
  user: null,

  init: function() {
    this._super();
    this.set('searchTerm', '');
  },

  uploadText: function() { return I18n.t("user.invited.bulk_invite.text"); }.property(),

  /**
    Observe the search term box with a debouncer and change the results.

    @observes searchTerm
  **/
  _searchTermChanged: Discourse.debounce(function() {
    var self = this;
    Discourse.Invite.findInvitedBy(self.get('user'), this.get('searchTerm')).then(function (invites) {
      self.set('model', invites);
    });
  }, 250).observes('searchTerm'),

  /**
    The maximum amount of invites that will be displayed in the view

    @property maxInvites
  **/
  maxInvites: Discourse.computed.setting('invites_shown'),

  /**
    Can the currently logged in user invite users to the site

    @property canInviteToForum
  **/
  canInviteToForum: function() {
    return Discourse.User.currentProp('can_invite_to_forum');
  }.property(),

  /**
    Can the currently logged in user bulk invite users to the site (only Admin is allowed to perform this operation)

    @property canBulkInvite
  **/
  canBulkInvite: function() {
    return Discourse.User.currentProp('admin');
  }.property(),

  /**
    Should the search filter input box be displayed?

    @property showSearch
  **/
  showSearch: Em.computed.gte('invites.length', 10),

  /**
    Were the results limited by our `maxInvites`

    @property truncated
  **/
  truncated: function() {
    return this.get('invites.length') === Discourse.SiteSettings.invites_shown;
  }.property('invites.length'),

  actions: {

    /**
      Rescind a given invite

      @method rescive
      @param {Discourse.Invite} invite the invite to rescind.
    **/
    rescind: function(invite) {
      invite.rescind();
      return false;
    }
  }

});
