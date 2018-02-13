import { ajax } from 'discourse/lib/ajax';
import AdminUser from 'admin/models/admin-user';
import { escapeExpression } from 'discourse/lib/utilities';

const StaffActionLog = Discourse.Model.extend({
  showFullDetails: false,

  actionName: function() {
    return I18n.t("admin.logs.staff_actions.actions." + this.get('action_name'));
  }.property('action_name'),

  formattedDetails: function() {
    let formatted = "";
    formatted += this.format('email', 'email');
    formatted += this.format('admin.logs.ip_address', 'ip_address');
    formatted += this.format('admin.logs.topic_id', 'topic_id');
    formatted += this.format('admin.logs.post_id', 'post_id');
    formatted += this.format('admin.logs.category_id', 'category_id');
    if (!this.get('useCustomModalForDetails')) {
      formatted += this.format('admin.logs.staff_actions.new_value', 'new_value');
      formatted += this.format('admin.logs.staff_actions.previous_value', 'previous_value');
    }
    if (!this.get('useModalForDetails')) {
      if (this.get('details')) formatted += escapeExpression(this.get('details')) + '<br/>';
    }
    return formatted;
  }.property('ip_address', 'email', 'topic_id', 'post_id', 'category_id'),

  format(label, propertyName) {
    if (this.get(propertyName)) {
      let value = escapeExpression(this.get(propertyName));
      if (propertyName === 'post_id') {
        value = `<a href data-link-post-id="${value}">${value}</a>`;
      }
      return `<b>${I18n.t(label)}:</b> ${value}<br/>`;
    } else {
      return '';
    }
  },

  useModalForDetails: function() {
    return (this.get('details') && this.get('details').length > 100);
  }.property('action_name'),

  useCustomModalForDetails: function() {
    return _.contains(['change_theme', 'delete_theme'], this.get('action_name'));
  }.property('action_name')
});

StaffActionLog.reopenClass({
  create: function(attrs) {
    attrs = attrs || {};

    if (attrs.acting_user) {
      attrs.acting_user = AdminUser.create(attrs.acting_user);
    }
    if (attrs.target_user) {
      attrs.target_user = AdminUser.create(attrs.target_user);
    }
    return this._super(attrs);
  },

  findAll: function(filters) {
    return ajax("/admin/logs/staff_action_logs.json", { data: filters }).then((data) => {
      return {
        staff_action_logs: data.staff_action_logs.map(function(s) {
          return StaffActionLog.create(s);
        }),
        user_history_actions: data.user_history_actions
      };
    });
  }
});

export default StaffActionLog;
