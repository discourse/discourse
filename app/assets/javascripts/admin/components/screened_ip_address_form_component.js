/**
  A form to create an IP address that will be blocked or whitelisted.
  Example usage:

    {{screened-ip-address-form action="recordAdded"}}

  where action is a callback on the controller or route that will get called after
  the new record is successfully saved. It is called with the new ScreenedIpAddress record
  as an argument.

  @class ScreenedIpAddressFormComponent
  @extends Ember.Component
  @namespace Discourse
  @module Discourse
**/
Discourse.ScreenedIpAddressFormComponent = Ember.Component.extend({
  classNames: ['screened-ip-address-form'],
  formSubmitted: false,
  actionName: 'block',

  actionNames: function() {
    return [
      {id: 'block',       name: I18n.t('admin.logs.screened_ips.actions.block')},
      {id: 'do_nothing',  name: I18n.t('admin.logs.screened_ips.actions.do_nothing')}
    ];
  }.property(),

  actions: {
    submit: function() {
      if (!this.get('formSubmitted')) {
        var self = this;
        this.set('formSubmitted', true);
        var screenedIpAddress = Discourse.ScreenedIpAddress.create({ip_address: this.get('ip_address'), action_name: this.get('actionName')});
        screenedIpAddress.save().then(function(result) {
          self.set('ip_address', '');
          self.set('formSubmitted', false);
          self.sendAction('action', Discourse.ScreenedIpAddress.create(result.screened_ip_address));
          Em.run.schedule('afterRender', function() { self.$('.ip-address-input').focus(); });
        }, function(e) {
          self.set('formSubmitted', false);
          var msg;
          if (e.responseJSON && e.responseJSON.errors) {
            msg = I18n.t("generic_error_with_reason", {error: e.responseJSON.errors.join('. ')});
          } else {
            msg = I18n.t("generic_error");
          }
          bootbox.alert(msg, function() { self.$('.ip-address-input').focus(); });
        });
      }
    }
  },

  didInsertElement: function(e) {
    var self = this;
    this._super();
    Em.run.schedule('afterRender', function() {
      self.$('.ip-address-input').keydown(function(e) {
        if (e.keyCode === 13) { // enter key
          self.send('submit');
        }
      });
    });
  }
});
