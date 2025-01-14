import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse/lib/decorators";
import { escapeExpression } from "discourse/lib/utilities";
import RestModel from "discourse/models/rest";
import { i18n } from "discourse-i18n";
import AdminUser from "admin/models/admin-user";

function format(label, value, escape = true) {
  return value
    ? `<b>${i18n(label)}</b>: ${escape ? escapeExpression(value) : value}`
    : "";
}

export default class StaffActionLog extends RestModel {
  static munge(json) {
    if (json.acting_user) {
      json.acting_user = AdminUser.create(json.acting_user);
    }
    if (json.target_user) {
      json.target_user = AdminUser.create(json.target_user);
    }
    return json;
  }

  static findAll(data) {
    return ajax("/admin/logs/staff_action_logs.json", { data }).then(
      (result) => {
        return {
          staff_action_logs: result.staff_action_logs.map((s) =>
            StaffActionLog.create(s)
          ),
          user_history_actions: result.user_history_actions,
        };
      }
    );
  }

  showFullDetails = false;

  @discourseComputed("action_name")
  actionName(actionName) {
    return i18n(`admin.logs.staff_actions.actions.${actionName}`);
  }

  @discourseComputed(
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

    const topicLink = topicId
      ? `<a href data-link-topic-id="${topicId}">${topicId}</a>`
      : null;

    let lines = [
      format("email", email),
      format("admin.logs.ip_address", ipAddress),
      format("admin.logs.topic_id", topicLink, false),
      format("admin.logs.post_id", postLink, false),
      format("admin.logs.category_id", categoryId),
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

    const formatted = lines.filter((l) => l.length > 0).join("<br/>");
    return formatted.length > 0 ? formatted + "<br/>" : "";
  }

  @discourseComputed("details")
  useModalForDetails(details) {
    return details && details.length > 100;
  }

  @discourseComputed("action_name")
  useCustomModalForDetails(actionName) {
    return [
      "change_theme",
      "delete_theme",
      "tag_group_create",
      "tag_group_destroy",
      "tag_group_change",
    ].includes(actionName);
  }
}
