(function() {

  window.Discourse.AdminUsersListController = Ember.ArrayController.extend(Discourse.Presence, {
    username: null,
    query: null,
    selectAll: false,
    content: null,

    selectAllChanged: (function() {
      var _this = this;
      return this.get('content').each(function(user) {
        return user.set('selected', _this.get('selectAll'));
      });
    }).observes('selectAll'),

    filterUsers: Discourse.debounce(function() {
      return this.refreshUsers();
    }, 250).observes('username'),

    orderChanged: (function() {
      return this.refreshUsers();
    }).observes('query'),

    showApproval: (function() {
      if (!Discourse.SiteSettings.must_approve_users) {
        return false;
      }
      if (this.get('query') === 'new') {
        return true;
      }
      if (this.get('query') === 'pending') {
        return true;
      }
    }).property('query'),

    selectedCount: (function() {
      if (this.blank('content')) {
        return 0;
      }
      return this.get('content').filterProperty('selected').length;
    }).property('content.@each.selected'),

    hasSelection: (function() {
      return this.get('selectedCount') > 0;
    }).property('selectedCount'),

    refreshUsers: function() {
      return this.set('content', Discourse.AdminUser.findAll(this.get('query'), this.get('username')));
    },

    show: function(term) {
      if (this.get('query') === term) {
        return this.refreshUsers();
      } else {
        return this.set('query', term);
      }
    },

    approveUsers: function() {
      return Discourse.AdminUser.bulkApprove(this.get('content').filterProperty('selected'));
    }
    
  });

}).call(this);
