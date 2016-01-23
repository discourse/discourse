import { propertyEqual } from 'discourse/lib/computed';

export default Ember.Controller.extend({
  taken: false,
  saving: false,
  error: false,
  success: false,
  newEmail: null,

  newEmailEmpty: Em.computed.empty('newEmail'),
  saveDisabled: Em.computed.or('saving', 'newEmailEmpty', 'taken', 'unchanged'),
  unchanged: propertyEqual('newEmailLower', 'currentUser.email'),

  newEmailLower: function() {
    return this.get('newEmail').toLowerCase().trim();
  }.property('newEmail'),

  saveButtonText: function() {
    if (this.get('saving')) return I18n.t("saving");
    return I18n.t("user.change");
  }.property('saving'),

  actions: {
    changeEmail: function() {
      var self = this;
      this.set('saving', true);
      return this.get('content').changeEmail(this.get('newEmail')).then(function() {
        self.set('success', true);
      }, function(e) {
        self.setProperties({ error: true, saving: false });
        if (e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors && e.jqXHR.responseJSON.errors[0]) {
          self.set('errorMessage', e.jqXHR.responseJSON.errors[0]);
        } else {
          self.set('errorMessage', I18n.t('user.change_email.error'));
        }
      });
    }
  }

});
