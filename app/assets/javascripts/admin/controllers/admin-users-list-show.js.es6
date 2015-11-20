import debounce from 'discourse/lib/debounce';
import { i18n } from 'discourse/lib/computed';

export default Ember.ArrayController.extend({
  query: null,
  showEmails: false,
  refreshing: false,
  listFilter: null,
  selectAll: false,

  queryNew: Em.computed.equal('query', 'new'),
  queryPending: Em.computed.equal('query', 'pending'),
  queryHasApproval: Em.computed.or('queryNew', 'queryPending'),
  showApproval: Em.computed.and('siteSettings.must_approve_users', 'queryHasApproval'),
  searchHint: i18n('search_hint'),
  hasSelection: Em.computed.gt('selectedCount', 0),

  selectedCount: function() {
    var model = this.get('model');
    if (!model || !model.length) return 0;
    return model.filterProperty('selected').length;
  }.property('model.@each.selected'),

  selectAllChanged: function() {
    var val = this.get('selectAll');
    this.get('model').forEach(function(user) {
      if (user.get('can_approve')) {
        user.set('selected', val);
      }
    });
  }.observes('selectAll'),

  title: function() {
    return I18n.t('admin.users.titles.' + this.get('query'));
  }.property('query'),

  _filterUsers: debounce(function() {
    this._refreshUsers();
  }, 250).observes('listFilter'),

  _refreshUsers: function() {
    var self = this;
    this.set('refreshing', true);

    Discourse.AdminUser.findAll(this.get('query'), { filter: this.get('listFilter'), show_emails: this.get('showEmails') }).then(function (result) {
      self.set('model', result);
    }).finally(function() {
      self.set('refreshing', false);
    });
  },

  actions: {
    approveUsers: function() {
      Discourse.AdminUser.bulkApprove(this.get('model').filterProperty('selected'));
      this._refreshUsers();
    },

    rejectUsers: function() {
      var maxPostAge = this.siteSettings.delete_user_max_post_age;
      var controller = this;
      Discourse.AdminUser.bulkReject(this.get('model').filterProperty('selected')).then(function(result){
        var message = I18n.t("admin.users.reject_successful", {count: result.success});
        if (result.failed > 0) {
          message += ' ' + I18n.t("admin.users.reject_failures", {count: result.failed});
          message += ' ' + I18n.t("admin.user.delete_forbidden", {count: maxPostAge});
        }
        bootbox.alert(message);
        controller._refreshUsers();
      });
    },

    showEmails: function() {
      this.set('showEmails', true);
      this._refreshUsers(true);
    }
  }

});
