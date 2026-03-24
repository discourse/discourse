import { computed } from "@ember/object";
import AdminUser from "discourse/admin/models/admin-user";
import { ajax } from "discourse/lib/ajax";
import { escapeExpression } from "discourse/lib/utilities";
import RestModel from "discourse/models/rest";
import { i18n } from "discourse-i18n";

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

  @computed("action_name")
  get actionName() {
    return i18n(`admin.logs.staff_actions.actions.${this.action_name}`);
  }

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
  get formattedDetails() {
    const postLink = this.post_id
      ? `<a href data-link-post-id="${this.post_id}">${this.post_id}</a>`
      : null;

    const topicLink = this.topic_id
      ? `<a href data-link-topic-id="${this.topic_id}">${this.topic_id}</a>`
      : null;

    let lines = [
      format("email", this.email),
      format("admin.logs.ip_address", this.ip_address),
      format("admin.logs.topic_id", topicLink, false),
      format("admin.logs.post_id", postLink, false),
      format("admin.logs.category_id", this.category_id),
    ];

    if (!this.useCustomModalForDetails) {
      lines.push(format("admin.logs.staff_actions.new_value", this.new_value));
      lines.push(
        format("admin.logs.staff_actions.previous_value", this.previous_value)
      );
    }

    if (!this.useModalForDetails && this.details) {
      lines = [...lines, ...escapeExpression(this.details).split("\n")];
    }

    const formatted = lines.filter((l) => l.length > 0).join("<br/>");
    return formatted.length > 0 ? formatted + "<br/>" : "";
  }

  @computed("details")
  get useModalForDetails() {
    return (
      this.details && (this.details.length > 100 || this.details.includes("\n"))
    );
  }

  @computed("action_name")
  get useCustomModalForDetails() {
    return [
      "change_theme",
      "delete_theme",
      "tag_group_create",
      "tag_group_destroy",
      "tag_group_change",
    ].includes(this.action_name);
  }
}
