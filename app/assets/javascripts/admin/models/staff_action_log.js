/**
  Represents an action taken by a staff member that has been logged.

  @class StaffActionLog
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.StaffActionLog = Discourse.Model.extend({
  showFullDetails: false,

  actionName: function() {
    return I18n.t("admin.logs.staff_actions.actions." + this.get('action_name'));
  }.property('action_name'),

  formattedDetails: function() {
    var formatted = "";
    if (this.get('email')) {
      formatted += "<b>" + I18n.t("email") + ":</b> " + this.get('email') + "<br/>";
    }
    if (this.get('ip_address')) {
      formatted += "<b>IP:</b> " + this.get('ip_address') + "<br/>";
    }
    return formatted;
  }.property('ip_address', 'email')
});

Discourse.StaffActionLog.reopenClass({
  create: function(attrs) {
    if (attrs.staff_user) {
      attrs.staff_user = Discourse.AdminUser.create(attrs.staff_user);
    }
    if (attrs.target_user) {
      attrs.target_user = Discourse.AdminUser.create(attrs.target_user);
    }
    return this._super(attrs);
  },

  findAll: function(filters) {
    return Discourse.ajax("/admin/logs/staff_action_logs.json", { data: filters }).then(function(staff_actions) {
      return staff_actions.map(function(s) {
        return Discourse.StaffActionLog.create(s);
      });
    });
  }
});
