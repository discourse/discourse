import EmailPreview from 'admin/models/email-preview';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend({

  emailEmpty: Em.computed.empty('email'),
  sendEmailDisabled: Em.computed.or('emailEmpty', 'sendingEmail'),
  showSendEmailForm: Em.computed.notEmpty('model.html_content'),
  htmlEmpty: Em.computed.empty('model.html_content'),

  iframeSrc: function() {
    return ('data:text/html;charset=utf-8,' + encodeURI(this.get('model.html_content')));
  }.property('model.html_content'),

  actions: {
    refresh() {
      const model = this.get('model');

      this.set('loading', true);
      this.set('sentEmail', false);
      EmailPreview.findDigest(this.get('lastSeen'), this.get('username')).then(email => {
        model.setProperties(email.getProperties('html_content', 'text_content'));
        this.set('loading', false);
      });
    },

    toggleShowHtml() {
      this.toggleProperty('showHtml');
    },

    sendEmail() {
      this.set('sendingEmail', true);
      this.set('sentEmail', false);

      const self = this;

      EmailPreview.sendDigest(this.get('lastSeen'), this.get('username'), this.get('email')).then(result => {
        if (result.errors) {
          bootbox.alert(result.errors);
        } else {
          self.set('sentEmail', true);
        }
      }).catch(popupAjaxError).finally(function() {
        self.set('sendingEmail', false);
      });
    }
  }

});
