import { setting, propertyEqual } from 'discourse/lib/computed';
import DiscourseURL from 'discourse/lib/url';

export default Ember.Controller.extend({
  taken: false,
  saving: false,
  error: false,
  errorMessage: null,
  newUsername: null,

  maxLength: setting('max_username_length'),
  minLength: setting('min_username_length'),
  newUsernameEmpty: Em.computed.empty('newUsername'),
  saveDisabled: Em.computed.or('saving', 'newUsernameEmpty', 'taken', 'unchanged', 'errorMessage'),
  unchanged: propertyEqual('newUsername', 'username'),

  checkTaken: function() {
    if( this.get('newUsername') && this.get('newUsername').length < this.get('minLength') ) {
      this.set('errorMessage', I18n.t('user.name.too_short'));
    } else {
      var self = this;
      this.set('taken', false);
      this.set('errorMessage', null);
      if (Ember.isEmpty(this.get('newUsername'))) return;
      if (this.get('unchanged')) return;
      Discourse.User.checkUsername(this.get('newUsername'), undefined, this.get('content.id')).then(function(result) {
        if (result.errors) {
          self.set('errorMessage', result.errors.join(' '));
        } else if (result.available === false) {
          self.set('taken', true);
        }
      });
    }
  }.observes('newUsername'),

  saveButtonText: function() {
    if (this.get('saving')) return I18n.t("saving");
    return I18n.t("user.change");
  }.property('saving'),

  actions: {
    changeUsername() {
      if (this.get('saveDisabled')) { return; }

      return bootbox.confirm(I18n.t("user.change_username.confirm"), 
                             I18n.t("no_value"),
                             I18n.t("yes_value"), result => {
        if (result) {
          this.set('saving', true);
          this.get('content').changeUsername(this.get('newUsername')).then(() => {
            DiscourseURL.redirectTo("/users/" + this.get('newUsername').toLowerCase() + "/preferences");
          })
          .catch(() => this.set('error', true))
          .finally(() => this.set('saving', false));
        }
      });
    }
  }

});


