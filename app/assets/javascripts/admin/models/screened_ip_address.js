/**
  Represents an IP address that is watched for during account registration
  (and possibly other times), and an action is taken.

  @class ScreenedIpAddress
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.ScreenedIpAddress = Discourse.Model.extend({
  actionName: function() {
    return I18n.t("admin.logs.screened_ips.actions." + this.get('action'));
  }.property('action'),

  isBlocked: function() {
    return (this.get('action') === 'block');
  }.property('action'),

  actionIcon: function() {
    if (this.get('action') === 'block') {
      return this.get('blockIcon');
    } else {
      return this.get('doNothingIcon');
    }
  }.property('action'),

  blockIcon: function() {
    return 'icon-remove';
  }.property(),

  doNothingIcon: function() {
    return 'icon-ok';
  }.property(),

  save: function() {
    return Discourse.ajax("/admin/logs/screened_ip_addresses/" + this.get('id') + ".json", {
      type: 'PUT',
      data: {ip_address: this.get('ip_address'), action_name: this.get('action')}
    });
  },

  destroy: function() {
    return Discourse.ajax("/admin/logs/screened_ip_addresses/" + this.get('id') + ".json", {type: 'DELETE'});
  }
});

Discourse.ScreenedIpAddress.reopenClass({
  findAll: function(filter) {
    return Discourse.ajax("/admin/logs/screened_ip_addresses.json").then(function(screened_ips) {
      return screened_ips.map(function(b) {
        return Discourse.ScreenedIpAddress.create(b);
      });
    });
  }
});
