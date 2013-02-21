(function() {

  /**
    This controller supports the interface for listing users in the admin section.

    @class AdminUsersListController    
    @extends Ember.ArrayController
    @namespace Discourse
    @module Discourse
  **/  
  window.Discourse.AdminUsersListController = Ember.ArrayController.extend(Discourse.Presence, {
    username: null,
    query: null,
    selectAll: false,
    content: null,

    selectAllChanged: (function() {
      var _this = this;
      this.get('content').each(function(user) {
        user.set('selected', _this.get('selectAll'));
      });
    }).observes('selectAll'),

    filterUsers: Discourse.debounce(function() {
      this.refreshUsers();
    }, 250).observes('username'),

    orderChanged: (function() {
      this.refreshUsers();
    }).observes('query'),

    showApproval: (function() {
      if (!Discourse.SiteSettings.must_approve_users) return false;
      if (this.get('query') === 'new') return true;
      if (this.get('query') === 'pending') return true;
    }).property('query'),

    selectedCount: (function() {
      if (this.blank('content')) return 0;
      return this.get('content').filterProperty('selected').length;
    }).property('content.@each.selected'),

    hasSelection: (function() {
      return this.get('selectedCount') > 0;
    }).property('selectedCount'),

    refreshUsers: function() {
      this.set('content', Discourse.AdminUser.findAll(this.get('query'), this.get('username')));
    },

    show: function(term) {
      if (this.get('query') === term) {
        this.refreshUsers();
        return;
      }

      this.set('query', term);
    },

    approveUsers: function() {
      Discourse.AdminUser.bulkApprove(this.get('content').filterProperty('selected'));
    }
    
  });

}).call(this);
