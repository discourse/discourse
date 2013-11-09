/**
  This controller supports the interface for listing screened IP addresses in the admin section.

  @class AdminLogsScreenedIpAddressesController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminLogsScreenedIpAddressesController = Ember.ArrayController.extend(Discourse.Presence, {
  loading: false,
  content: [],
  itemController: 'adminLogsScreenedIpAddress',

  show: function() {
    var self = this;
    this.set('loading', true);
    Discourse.ScreenedIpAddress.findAll().then(function(result) {
      self.set('content', result);
      self.set('loading', false);
    });
  },

  actions: {
    recordAdded: function(arg) {
      this.get("content").unshiftObject(arg);
    }
  }
});

Discourse.AdminLogsScreenedIpAddressController = Ember.ObjectController.extend({
  editing: false,
  savedIpAddress: null,

  actions: {
    allow: function(record) {
      record.set('action_name', 'do_nothing');
      this.send('save', record);
    },

    block: function(record) {
      record.set('action_name', 'block');
      this.send('save', record);
    },

    edit: function() {
      if (!this.get('editing')) {
        this.savedIpAddress = this.get('ip_address');
      }
      this.set('editing', true);
    },

    cancel: function() {
      if (this.get('savedIpAddress') && this.get('editing')) {
        this.set('ip_address', this.get('savedIpAddress'));
      }
      this.set('editing', false);
    },

    save: function(record) {
      var self = this;
      var wasEditing = this.get('editing');
      this.set('editing', false);
      record.save().then(function(saved){
        if (saved.success) {
          self.set('savedIpAddress', null);
        } else {
          bootbox.alert(saved.errors);
          if (wasEditing) self.set('editing', true);
        }
      }, function(e){
        if (e.responseJSON && e.responseJSON.errors) {
          bootbox.alert(I18n.t("generic_error_with_reason", {error: e.responseJSON.errors.join('. ')}));
        } else {
          bootbox.alert(I18n.t("generic_error"));
        }
        if (wasEditing) self.set('editing', true);
      });
    },

    destroy: function(record) {
      var self = this;
      return bootbox.confirm(I18n.t("admin.logs.screened_ips.delete_confirm", {ip_address: record.get('ip_address')}), I18n.t("no_value"), I18n.t("yes_value"), function(result) {
        if (result) {
          record.destroy().then(function(deleted) {
            if (deleted) {
              self.get("parentController.content").removeObject(record);
            } else {
              bootbox.alert(I18n.t("generic_error"));
            }
          }, function(e){
            bootbox.alert(I18n.t("generic_error_with_reason", {error: "http: " + e.status + " - " + e.body}));
          });
        }
      });
    }
  }
});