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
    return I18n.t("admin.logs.screened_ips.actions." + this.get('action_name'));
  }.property('action_name'),

  isBlocked: function() {
    return (this.get('action_name') === 'block');
  }.property('action_name'),

  actionIcon: function() {
    if (this.get('action_name') === 'block') {
      return this.get('blockIcon');
    } else {
      return this.get('doNothingIcon');
    }
  }.property('action_name'),

  blockIcon: function() {
    return 'icon-ban-circle';
  }.property(),

  doNothingIcon: function() {
    return 'icon-ok';
  }.property(),

  save: function() {
    return Discourse.ajax("/admin/logs/screened_ip_addresses" + (this.id ? '/' + this.id : '') + ".json", {
      type: this.id ? 'PUT' : 'POST',
      data: {ip_address: this.get('ip_address'), action_name: this.get('action_name')}
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
