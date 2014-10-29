/**
  This controller supports the interface for listing users in the admin section.

  @class AdminUsersListController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
export default Ember.ArrayController.extend(Discourse.Presence, {
  username: null,
  query: null,
  selectAll: false,
  content: null,
  loading: false,

  mustApproveUsers: Discourse.computed.setting('must_approve_users'),
  queryNew: Em.computed.equal('query', 'new'),
  queryPending: Em.computed.equal('query', 'pending'),
  queryHasApproval: Em.computed.or('queryNew', 'queryPending'),

  searchHint: function() { return I18n.t("search_hint"); }.property(),

  /**
    Triggered when the selectAll property is changed

    @event selectAll
  **/
  selectAllChanged: function() {
    var _this = this;
    _.each(this.get('content'),function(user) {
      user.set('selected', _this.get('selectAll'));
    });
  }.observes('selectAll'),

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
  orderChanged: function() {
    this.refreshUsers();
  }.observes('query'),

  /**
    The title of the user list, based on which query was performed.

    @property title
  **/
  title: function() {
    return I18n.t('admin.users.titles.' + this.get('query'));
  }.property('query'),

  /**
    Do we want to show the approval controls?

    @property showApproval
  **/
  showApproval: function() {
    return Discourse.SiteSettings.must_approve_users && this.get('queryHasApproval');
  }.property('queryPending'),

  /**
    How many users are currently selected

    @property selectedCount
  **/
  selectedCount: function() {
    if (this.blank('content')) return 0;
    return this.get('content').filterProperty('selected').length;
  }.property('content.@each.selected'),

  /**
    Do we have any selected users?

    @property hasSelection
  **/
  hasSelection: Em.computed.gt('selectedCount', 0),

  /**
    Refresh the current list of users.

    @method refreshUsers
  **/
  refreshUsers: function() {
    var adminUsersListController = this;
    adminUsersListController.set('loading', true);

    Discourse.AdminUser.findAll(this.get('query'), { filter: this.get('username') }).then(function (result) {
      adminUsersListController.set('content', result);
      adminUsersListController.set('loading', false);
    });
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
    this.refreshUsers();
  },

  /**
    Reject all the currently selected users.

    @method rejectUsers
  **/
  rejectUsers: function() {
    var controller = this;
    Discourse.AdminUser.bulkReject(this.get('content').filterProperty('selected')).then(function(result){
      var message = I18n.t("admin.users.reject_successful", {count: result.success});
      if (result.failed > 0) {
        message += ' ' + I18n.t("admin.users.reject_failures", {count: result.failed});
        message += ' ' + I18n.t("admin.user.delete_forbidden", {count: Discourse.SiteSettings.delete_user_max_post_age});
      }
      bootbox.alert(message);
      controller.refreshUsers();
    });
  }

});
