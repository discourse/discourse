import computed from "ember-addons/ember-computed-decorators";
import { ajax } from "discourse/lib/ajax";
import AdminUser from "admin/models/admin-user";
import { escapeExpression } from "discourse/lib/utilities";

function format(label, value, escape = true) {
  return value
    ? `<b>${I18n.t(label)}</b>: ${escape ? escapeExpression(value) : value}`
    : "";
}

const StaffActionLog = Discourse.Model.extend({
  showFullDetails: false,

  @computed("action_name")
  actionName(actionName) {
    return I18n.t(`admin.logs.staff_actions.actions.${actionName}`);
  },

  @computed(
    "email",
    "ip_address",
    "topic_id",
    "post_id",
    "category_id",
    "new_value",
    "previous_value",
    "details",
    "useCustomModalForDetails",
    "useModalForDetails"
  )
  formattedDetails(
    email,
    ipAddress,
    topicId,
    postId,
    categoryId,
    newValue,
    previousValue,
    details,
    useCustomModalForDetails,
    useModalForDetails
  ) {
    const postLink = postId
      ? `<a href data-link-post-id="${postId}">${postId}</a>`
      : null;

    let lines = [
      format("email", email),
      format("admin.logs.ip_address", ipAddress),
      format("admin.logs.topic_id", topicId),
      format("admin.logs.post_id", postLink, false),
      format("admin.logs.category_id", categoryId)
    ];

    if (!useCustomModalForDetails) {
      lines.push(format("admin.logs.staff_actions.new_value", newValue));
      lines.push(
        format("admin.logs.staff_actions.previous_value", previousValue)
      );
    }

    if (!useModalForDetails && details) {
      lines = [...lines, ...escapeExpression(details).split("\n")];
    }

    const formatted = lines.filter(l => l.length > 0).join("<br/>");
    return formatted.length > 0 ? formatted + "<br/>" : "";
  },

  @computed("details")
  useModalForDetails(details) {
    return details && details.length > 100;
  },

  @computed("action_name")
  useCustomModalForDetails(actionName) {
    return ["change_theme", "delete_theme"].includes(actionName);
  }
});

StaffActionLog.reopenClass({
  create(attrs) {
    attrs = attrs || {};

    if (attrs.acting_user) {
      attrs.acting_user = AdminUser.create(attrs.acting_user);
    }
    if (attrs.target_user) {
      attrs.target_user = AdminUser.create(attrs.target_user);
    }
    return this._super(attrs);
  },

  findAll(data) {
    return ajax("/admin/logs/staff_action_logs.json", { data }).then(result => {
      return {
        staff_action_logs: result.staff_action_logs.map(s =>
          StaffActionLog.create(s)
        ),
        user_history_actions: result.user_history_actions
      };
    });
  }
});

export default StaffActionLog;
