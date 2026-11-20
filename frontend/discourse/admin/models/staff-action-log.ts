import { computed } from "@ember/object";
import AdminUser, {
  type BasicAdminUser,
} from "discourse/admin/models/admin-user";
import { ajax } from "discourse/lib/ajax";
import { duration, longDate } from "discourse/lib/formatter";
import getURL from "discourse/lib/get-url";
import { escapeExpression } from "discourse/lib/utilities";
import RestModel, {
  type RestModelClass,
  type RestModelStoreAttrs,
  type RestPayload,
} from "discourse/models/rest";
import { i18n } from "discourse-i18n";

/** Parsed theme/tag-group JSON or the text used by other history actions. */
export type StaffActionValue =
  | string
  | number
  | boolean
  | null
  | StaffActionValue[]
  | { [key: string]: StaffActionValue };

/** Viewer-redacted history rows; reviewable_id is conditionally serialized. */
export interface StaffActionLogFields {
  id?: number;
  action_name: string;
  action: number;
  details: string | null;
  context?: string | null;
  ip_address?: string | null;
  email?: string | null;
  created_at?: string;
  expires_at: string | null;
  subject?: string | null;
  previous_value?: StaffActionValue;
  new_value?: StaffActionValue;
  topic_id?: number | null;
  post_id?: number | null;
  category_id?: number | null;
  reviewable_id?: number;
  custom_type: string | null;
  acting_user: AdminUser | null;
  target_user: AdminUser | null;
}

/** munge hydrates actors on the store and inherited create paths. */
export type StaffActionLogCreateAttrs<M = StaffActionLog> = Partial<
  Omit<M, "acting_user" | "target_user">
> &
  RestModelStoreAttrs &
  RestPayload & {
    acting_user?: BasicAdminUser | AdminUser | null;
    target_user?: BasicAdminUser | AdminUser | null;
  };

/** The unused findAll reads this at the top level, although the controller sends it under extras. */
export interface StaffActionLogListResponse {
  staff_action_logs: StaffActionLog[];
  user_history_actions: { id: string; action_id: number }[] | undefined;
}

function format(
  label: string,
  value: StaffActionValue | undefined,
  escape = true
) {
  const labelBr = value && value.toString().includes("\n") ? "<br/>" : " ";
  value = value ? value.toString() : "";
  return value
    ? `<b>${i18n(label)}:</b>${labelBr} ${escape ? escapeExpression(value.replaceAll("\n", "<br/>")) : value.replaceAll("\n", "<br/>")}`
    : "";
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface StaffActionLog extends StaffActionLogFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class StaffActionLog extends RestModel {
  declare static create: <C extends RestModelClass>(
    this: C,
    attrs?: StaffActionLogCreateAttrs<InstanceType<C>>
  ) => InstanceType<C>;

  static munge(json: StaffActionLogCreateAttrs): RestPayload;
  static munge(json: RestPayload): RestPayload;
  static munge(json: StaffActionLogCreateAttrs) {
    if (json.acting_user) {
      json.acting_user = AdminUser.create(json.acting_user);
    }
    if (json.target_user) {
      json.target_user = AdminUser.create(json.target_user);
    }
    return json;
  }

  static findAll(
    data?: Record<string, string | number | boolean>
  ): Promise<StaffActionLogListResponse> {
    return ajax("/admin/logs/staff_action_logs.json", { data }).then(
      (result: {
        staff_action_logs: StaffActionLogCreateAttrs[];
        user_history_actions?: StaffActionLogListResponse["user_history_actions"];
      }) => {
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
  get actionName(): string {
    return i18n(`admin.logs.staff_actions.actions.${this.action_name}`);
  }

  @computed(
    "email",
    "ip_address",
    "topic_id",
    "post_id",
    "category_id",
    "reviewable_id",
    "new_value",
    "previous_value",
    "details",
    "created_at",
    "expires_at",
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

    const reviewableLink = this.reviewable_id
      ? `<a href="${getURL(`/review/${this.reviewable_id}`)}">${this.reviewable_id}</a>`
      : null;

    let lines = [
      format("email", this.email),
      format("admin.logs.ip_address", this.ip_address),
      format("admin.logs.topic_id", topicLink, false),
      format("admin.logs.post_id", postLink, false),
      format("admin.logs.category_id", this.category_id),
      format("admin.logs.reviewable_id", reviewableLink, false),
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

    if (this.created_at && this.expires_at) {
      const created = moment(this.created_at);
      const expires = moment(this.expires_at);
      if (
        created.isValid() &&
        expires.isValid() &&
        expires.isSameOrAfter(created)
      ) {
        const indefinite = expires.diff(created, "years") > 100;
        lines.push(
          format(
            "admin.logs.staff_actions.scheduled_duration",
            indefinite
              ? i18n("admin.logs.staff_actions.indefinite")
              : duration(expires.diff(created, "seconds"), { format: "medium" })
          )
        );
        if (!indefinite) {
          lines.push(
            format(
              "admin.logs.staff_actions.scheduled_expiry",
              longDate(expires)
            )
          );
        }
      }
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

declare module "discourse/services/store" {
  interface ModelRegistry {
    "staff-action-log": StaffActionLog;
  }
  interface ModelCreateAttrsRegistry {
    "staff-action-log": StaffActionLogCreateAttrs;
  }
}

/** Legacy application global; declaring it preserves the module evaluation order. */
declare const moment: typeof import("moment");
