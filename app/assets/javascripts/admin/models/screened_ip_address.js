/**
  Represents an IP address that is watched for during account registration
  (and possibly other times), and an action is taken.

  @class ScreenedIpAddress
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.ScreenedIpAddress = Discourse.Model.extend({
  // TODO: this is repeated in all 3 screened models. move it.
  actionName: function() {
    if (this.get('action') === 'do_nothing') {
      return I18n.t("admin.logs.screened_ips.allow");
    } else {
      return I18n.t("admin.logs.screened_actions." + this.get('action'));
    }
  }.property('action')
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
