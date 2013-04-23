/**
  This controller supports the interface for listing users in the admin section.

  @class AdminUsersListController    
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/  
Discourse.AdminUsersListController = Ember.ArrayController.extend(Discourse.Presence, {
  username: null,
  query: null,
  selectAll: false,
  content: null,
  loading: false,

  /**
    Triggered when the selectAll property is changed

    @event selectAll
  **/
  selectAllChanged: (function() {
    var _this = this;
    this.get('content').each(function(user) {
      user.set('selected', _this.get('selectAll'));
    });
  }).observes('selectAll'),

  /**
    Triggered when the username filter is changed

    @event filterUsers
  **/
  filterUsers: Discourse.debounce(function() {
    this.refreshUsers();
  }, 250).observes('username'),

  /**
    Triggered when the order of the users list is changed

    @event orderChanged
  **/
  orderChanged: (function() {
    this.refreshUsers();
  }).observes('query'),

  /**
    The title of the user list, based on which query was performed.

    @property title
  **/
  title: function() {
    return Em.String.i18n('admin.users.titles.' + this.get('query'));
  }.property('query'),

  /**
    Do we want to show the approval controls?

    @property showApproval
  **/
  showApproval: (function() {
    if (!Discourse.SiteSettings.must_approve_users) return false;
    if (this.get('query') === 'new') return true;
    if (this.get('query') === 'pending') return true;
  }).property('query'),

  /**
    How many users are currently selected

    @property selectedCount
  **/
  selectedCount: (function() {
    if (this.blank('content')) return 0;
    return this.get('content').filterProperty('selected').length;
  }).property('content.@each.selected'),

  /**
    Do we have any selected users?

    @property hasSelection
  **/
  hasSelection: (function() {
    return this.get('selectedCount') > 0;
  }).property('selectedCount'),

  /**
    Refresh the current list of users.

    @method refreshUsers
  **/
  refreshUsers: function() {
    this.set('loading', true);
    var _this = this;
    this.set('content', Discourse.AdminUser.findAll(this.get('query'), this.get('username'), function() { _this.set('loading', false); }));
  },


  /**
    Show the list of users.

    @method show
  **/
  show: function(term) {
    if (this.get('query') === term) {
      this.refreshUsers();
      return;
    }
    this.set('query', term);
  },

  /**
    Approve all the currently selected users.

    @method approveUsers
  **/
  approveUsers: function() {
    Discourse.AdminUser.bulkApprove(this.get('content').filterProperty('selected'));
  }
  
});
