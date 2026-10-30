import { computed } from "@ember/object";
import type { Tl3RequirementsFields } from "discourse/admin/models/tl3-requirements";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import { deepEqual } from "discourse/lib/object";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import { applyBehaviorTransformer } from "discourse/lib/transformer";
import { userPath } from "discourse/lib/url";
import type { GroupFields } from "discourse/models/group";
import User, { type UserFields, type UserGroup } from "discourse/models/user";
import { i18n } from "discourse-i18n";

/** Embedded basic users are data records, not hydrated User instances. */
export type BasicAdminUser = Pick<
  UserFields,
  "id" | "username" | "avatar_template" | "name"
> & { status?: User["status"] };

/** BasicGroup serializer data; the inherited UserGroup identity contract stays required. */
export type AdminUserGroup = UserGroup & GroupFields & { user_count?: number };

/** Export serialization can omit the envelope when there is no upload. */
export interface AdminUserExport {
  id: number;
  filename: string;
  uri: string;
  filesize: number;
  extension: string;
  retain_hours: number;
  human_filesize: string;
}

/** Core admin serializer additions; plugins augment this interface. All admin additions can be absent on basic users. */
export interface AdminUserFields extends UserFields {
  active?: boolean;
  approved?: boolean;
  last_emailed_at?: string | null;
  last_seen_age?: number | null;
  last_emailed_age?: number | null;
  created_at_age?: number;
  manual_locked_trust_level?: number | null;
  can_be_suspended?: boolean;
  can_send_activation_email?: boolean;
  can_activate?: boolean;
  can_deactivate?: boolean;
  can_approve?: boolean;
  can_change_trust_level?: boolean;
  ip_address?: string | null;
  registration_ip_address?: string | null;
  include_ip?: boolean | null;
  can_grant_admin?: boolean;
  can_revoke_admin?: boolean;
  can_grant_moderation?: boolean;
  can_revoke_moderation?: boolean;
  can_impersonate?: boolean;
  can_be_anonymized?: boolean;
  can_be_merged?: boolean;
  like_count?: number;
  like_given_count?: number;
  post_edits_count?: number | null;
  flags_given_count?: number;
  flags_received_count?: number;
  private_topics_count?: number;
  warnings_received_count?: number;
  full_suspend_reason?: string | null;
  suspended_at?: string | null;
  full_silence_reason?: string | null;
  silenced_at?: string | null;
  /** The detail serializer emits no total, unlike the embedded TL3 serializer. */
  penalty_counts?: { silenced: number; suspended: number };
  next_penalty?: string | null;
  bounce_score?: number;
  reset_bounce_score_after?: string | null;
  can_view_action_logs?: boolean;
  can_disable_second_factor?: boolean;
  can_delete_sso_record?: boolean;
  api_key_count?: number;
  /** Sent only to admins listing bots, for bots whose creator was recorded. */
  bot_creator?: { username: string; avatar_template: string; url: string };
  external_ids?: Record<string, string>;
  similar_users_count?: number;
  /** Captures contain only null; accept wrapped, unwrapped and empty export serialization conservatively. */
  latest_export?:
    | (Partial<AdminUserExport> & { user_export?: Partial<AdminUserExport> })
    | null;
  upcoming_changes_stats?: {
    name: string;
    humanized_name: string;
    description: string;
    enabled: boolean;
    specific_groups: string[];
    reason:
      | "enabled_for_everyone"
      | "enabled_for_no_one"
      | "in_specific_groups"
      | "not_in_specific_groups";
  }[];
  single_sign_on_record?: {
    user_id: number;
    external_id: string;
    created_at: string;
    updated_at: string;
    external_username: string | null;
    external_name: string | null;
    external_avatar_url: string | null;
    external_profile_background_url: string | null;
    external_card_background_url: string | null;
  } | null;
  approved_by?: BasicAdminUser | null;
  suspended_by?: BasicAdminUser | null;
  silenced_by?: BasicAdminUser | null;
  tl3_requirements?: Tl3RequirementsFields;
  loadedDetails?: boolean;
  originalTrustLevel?: number;
  selected?: boolean;
  silencingUser?: boolean;
}

/** Raw serializer data also includes fields User declares separately as tracked members. */
export interface AdminUserWireFields extends AdminUserFields {
  groups?: AdminUserGroup[];
  visibleGroups?: AdminUserGroup[];
  secondary_emails?: User["secondary_emails"];
  associated_accounts?: User["associated_accounts"];
  status?: User["status"];
}

/** Detail response after find marks it loaded and moves groups to visibleGroups. */
export interface AdminUserDetails extends AdminUserWireFields {
  loadedDetails: boolean;
}

/** List endpoint filters; query selects the list name separately. */
export interface AdminUserFilter {
  filter?: string;
  show_emails?: boolean;
  page?: number;
  [key: string]: string | number | boolean | undefined;
}

/** Shared penalty form inputs; suspend and silence use different expiry keys. */
export interface AdminUserPenaltyParams {
  reason?: string;
  message?: string;
  post_id?: number;
  reviewable_id?: number;
  post_action?: string;
  post_edit?: string;
  other_user_ids?: number[];
  [key: string]: unknown;
}

type Suspension = Pick<
  AdminUserFields,
  | "suspend_reason"
  | "full_suspend_reason"
  | "suspended_till"
  | "suspended_at"
  | "suspended_by"
>;
type Silencing = Pick<
  AdminUserFields,
  | "silence_reason"
  | "full_silence_reason"
  | "silenced_till"
  | "silenced_at"
  | "silenced_by"
>;
type SuccessResponse = { success: string | boolean };

/** A failed deletion can return refreshed user data; the catch resolves without a value. */
export interface AdminUserDestroyResult {
  deleted: boolean;
  user?: AdminUserWireFields;
  message?: string;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface AdminUser extends AdminUserFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class AdminUser extends User {
  /** Raw lookups return enumerable response data for setProperties rather than an instance. */
  static find(
    user_id: string | number,
    opts: { raw: true }
  ): Promise<AdminUserDetails>;

  static find(
    user_id: string | number,
    opts?: { raw?: false } | null
  ): Promise<AdminUser>;

  static find(
    user_id: string | number,
    opts: { raw?: boolean } | null
  ): Promise<AdminUserDetails | AdminUser>;

  static async find(
    user_id: string | number,
    opts: { raw?: boolean } | null = { raw: false }
  ): Promise<AdminUserDetails | AdminUser> {
    const result = await ajax<AdminUserDetails>(`/admin/users/${user_id}.json`);
    result.loadedDetails = true;

    if (Object.hasOwn(result, "groups")) {
      result.visibleGroups = result.groups;
      delete result.groups;
    }

    return opts?.raw ? result : AdminUser.create(result);
  }

  static findAll(
    query: string,
    userFilter?: AdminUserFilter
  ): Promise<AdminUser[]> {
    return ajax(`/admin/users/list/${query}.json`, {
      data: userFilter,
    }).then((users: AdminUserWireFields[]) =>
      users.map((u) => AdminUser.create(u))
    );
  }

  adminUserView = true;

  @autoTrackedArray visibleGroups: AdminUserGroup[] | undefined;

  @computed("active", "staged")
  get canViewProfile() {
    return this.active || this.staged;
  }

  @computed("bounce_score")
  get canResetBounceScore() {
    // Missing scores retain JavaScript comparison semantics on partial instances.
    return this.bounce_score! > 0;
  }

  @computed("originalTrustLevel", "trust_level")
  get dirty() {
    return !deepEqual(this.originalTrustLevel, this.trust_level);
  }

  @computed("trust_level")
  get canLockTrustLevel() {
    return this.trust_level! < 4;
  }

  @computed("staff")
  get canSuspend() {
    return !this.staff;
  }

  @computed("staff")
  get canSilence() {
    return !this.staff;
  }

  get customGroups() {
    return this.visibleGroups?.filter((g) => !g.automatic) ?? [];
  }

  get automaticGroups() {
    return this.visibleGroups?.filter((g) => g.automatic) ?? [];
  }

  @computed("bounce_score", "reset_bounce_score_after")
  get bounceScore() {
    if (this.bounce_score! > 0) {
      return `${this.bounce_score} - ${moment(
        this.reset_bounce_score_after
      ).format("LL")}`;
    } else {
      return this.bounce_score;
    }
  }

  @computed("bounce_score")
  get bounceScoreExplanation(): string {
    // TODO(typescript-pending): site settings expose unknown values; remove the assertion when bounce_score_threshold is typed.
    if (this.bounce_score === 0) {
      return i18n("admin.user.bounce_score_explanation.none");
    } else if (
      this.bounce_score! < (this.siteSettings.bounce_score_threshold as number)
    ) {
      return i18n("admin.user.bounce_score_explanation.some");
    } else {
      return i18n("admin.user.bounce_score_explanation.threshold_reached");
    }
  }

  @computed
  get bounceLink(): string {
    return getURL("/admin/email-logs/bounced");
  }

  @computed("suspended_till", "suspended_at")
  get suspendDuration() {
    const suspendedAt = moment(this.suspended_at);
    const suspendedTill = moment(this.suspended_till);
    return suspendedAt.format("L") + " - " + suspendedTill.format("L");
  }

  @computed("tl3_requirements")
  get tl3Requirements() {
    if (this.tl3_requirements) {
      return this.store.createRecord("tl3Requirements", this.tl3_requirements);
    }
  }

  @computed("suspended_by")
  get suspendedBy(): AdminUser | null {
    return this.suspended_by ? AdminUser.create(this.suspended_by) : null;
  }

  @computed("silenced_by")
  get silencedBy(): AdminUser | null {
    return this.silenced_by ? AdminUser.create(this.silenced_by) : null;
  }

  @computed("approved_by")
  get approvedBy(): AdminUser | null {
    return this.approved_by ? AdminUser.create(this.approved_by) : null;
  }

  resetBounceScore() {
    return ajax(`/admin/users/${this.id}/reset-bounce-score`, {
      type: "POST",
    }).then(() =>
      this.setProperties({
        bounce_score: 0,
        reset_bounce_score_after: null,
      })
    );
  }

  async groupAdded(added: AdminUserGroup) {
    await ajax(`/admin/users/${this.id}/groups`, {
      type: "POST",
      data: { group_id: added.id },
    });

    this.visibleGroups!.push(added);
  }

  groupRemoved(groupId: number) {
    return ajax(`/admin/users/${this.id}/groups/${groupId}`, {
      type: "DELETE",
    }).then(() => {
      this.visibleGroups = this.visibleGroups!.filter(
        (group) => group.id !== groupId
      );
      if (this.primary_group_id === groupId) {
        this.set("primary_group_id", null);
      }
    });
  }

  deleteAllPosts(): Promise<{ posts_deleted: number }> {
    return ajax(`/admin/users/${this.get("id")}/delete_posts_batch`, {
      type: "PUT",
    });
  }

  deleteAllPostsDecider(): Promise<{
    job_enqueued: boolean;
    post_count: number;
  }> {
    return ajax(`/admin/users/${this.get("id")}/delete_posts_decider`, {
      type: "POST",
    });
  }

  revokeAdmin() {
    return ajax(`/admin/users/${this.id}/revoke_admin`, {
      type: "PUT",
    }).then((resp: AdminUserWireFields) => {
      this.setProperties({
        admin: false,
        can_grant_admin: true,
        can_revoke_admin: false,
        can_be_merged: resp.can_be_merged,
        can_be_anonymized: resp.can_be_anonymized,
        can_be_deleted: resp.can_be_deleted,
        can_delete_all_posts: resp.can_delete_all_posts,
      });
    });
  }

  grantAdmin(data?: {
    email_confirmation_token?: string;
    [key: string]: unknown;
  }) {
    return ajax(`/admin/users/${this.id}/grant_admin`, {
      type: "PUT",
      data,
    }).then(
      (resp: SuccessResponse & { email_confirmation_required?: boolean }) => {
        if (resp.success && !resp.email_confirmation_required) {
          this.setProperties({
            admin: true,
            can_grant_admin: false,
            can_revoke_admin: true,
          });
        }

        return resp;
      }
    );
  }

  revokeModeration() {
    return ajax(`/admin/users/${this.id}/revoke_moderation`, {
      type: "PUT",
    })
      .then((resp: AdminUserWireFields) => {
        this.setProperties({
          moderator: false,
          can_grant_moderation: true,
          can_revoke_moderation: false,
          can_be_merged: resp.can_be_merged,
          can_be_anonymized: resp.can_be_anonymized,
        });
      })
      .catch(popupAjaxError);
  }

  grantModeration() {
    return ajax(`/admin/users/${this.id}/grant_moderation`, {
      type: "PUT",
    })
      .then((resp: AdminUserWireFields) => {
        this.setProperties({
          moderator: true,
          can_grant_moderation: false,
          can_revoke_moderation: true,
          can_be_merged: resp.can_be_merged,
          can_be_anonymized: resp.can_be_anonymized,
        });
      })
      .catch(popupAjaxError);
  }

  disableSecondFactor() {
    return ajax(`/admin/users/${this.id}/disable_second_factor`, {
      type: "PUT",
    })
      .then(() => {
        this.set("second_factor_enabled", false);
      })
      .catch(popupAjaxError);
  }

  approve(approvedBy: BasicAdminUser) {
    return ajax(`/admin/users/${this.id}/approve`, {
      type: "PUT",
    }).then(() => {
      this.setProperties({
        can_approve: false,
        approved: true,
        approved_by: approvedBy,
      });
    });
  }

  setOriginalTrustLevel() {
    this.set("originalTrustLevel", this.trust_level);
  }

  saveTrustLevel(): Promise<{ admin_user: AdminUserWireFields }> {
    return ajax(`/admin/users/${this.id}/trust_level`, {
      type: "PUT",
      data: { level: this.trust_level },
    });
  }

  restoreTrustLevel() {
    this.set("trust_level", this.originalTrustLevel);
  }

  lockTrustLevel(locked: boolean): Promise<unknown> {
    return ajax(`/admin/users/${this.id}/trust_level_lock`, {
      type: "PUT",
      data: { locked: !!locked },
    });
  }

  suspend(data: AdminUserPenaltyParams & { suspend_until: string }) {
    return ajax(`/admin/users/${this.id}/suspend`, {
      type: "PUT",
      data,
    }).then((result: { suspension: Suspension }) =>
      this.setProperties(result.suspension)
    );
  }

  unsuspend() {
    return applyBehaviorTransformer(
      "admin-user-unsuspend",
      () =>
        ajax(`/admin/users/${this.id}/unsuspend`, {
          type: "PUT",
        }).then((result: { suspension: Suspension }) =>
          this.setProperties(result.suspension)
        ),
      { user: this }
    );
  }

  logOut(): Promise<SuccessResponse> {
    return ajax("/admin/users/" + this.id + "/log_out", {
      type: "POST",
      data: { username_or_email: this.username },
    });
  }

  impersonate(): Promise<unknown> {
    return ajax("/admin/impersonate", {
      type: "POST",
      data: { username_or_email: this.username },
    });
  }

  activate(): Promise<SuccessResponse> {
    return ajax(`/admin/users/${this.id}/activate`, {
      type: "PUT",
    });
  }

  deactivate(): Promise<SuccessResponse> {
    return ajax(`/admin/users/${this.id}/deactivate`, {
      type: "PUT",
      data: { context: document.location.pathname },
    });
  }

  unsilence() {
    return applyBehaviorTransformer(
      "admin-user-unsilence",
      () => {
        this.set("silencingUser", true);

        return ajax(`/admin/users/${this.id}/unsilence`, {
          type: "PUT",
        })
          .then(
            (result: {
              unsilence: Silencing & {
                silence_at?: undefined;
                silence_till?: undefined;
              };
            }) => {
              this.setProperties({
                silence_reason: result.unsilence.silence_reason,
                full_silence_reason: result.unsilence.full_silence_reason,
                silenced_at: result.unsilence.silence_at,
                silenced_till: result.unsilence.silence_till,
              });
            }
          )
          .finally(() => this.set("silencingUser", false));
      },
      { user: this }
    );
  }

  silence(data: AdminUserPenaltyParams & { silenced_till: string }) {
    this.set("silencingUser", true);

    return ajax(`/admin/users/${this.id}/silence`, {
      type: "PUT",
      data,
    })
      .then((result: { silence: Silencing }) => {
        this.setProperties({
          silence_reason: result.silence.silence_reason,
          full_silence_reason: result.silence.full_silence_reason,
          silenced_at: result.silence.silenced_at,
          silenced_by: result.silence.silenced_by,
          silenced_till: result.silence.silenced_till,
        });
      })
      .finally(() => this.set("silencingUser", false));
  }

  sendActivationEmail(): Promise<unknown> {
    return ajax(userPath("action/send_activation_email"), {
      type: "POST",
      data: { username: this.username },
    });
  }

  anonymize(): Promise<
    | (SuccessResponse & { username: string })
    | { failed: string; user: AdminUserWireFields | null }
  > {
    return ajax(`/admin/users/${this.id}/anonymize.json`, {
      type: "PUT",
    });
  }

  deleteAssociatedAccounts() {
    return ajax(`/admin/users/${this.id}/delete_associated_accounts`, {
      type: "PUT",
      data: {
        context: window.location.pathname,
      },
    }).then(() => {
      this.set("associated_accounts", []);
    });
  }

  /** The unreachable overload preserves the inherited framework destruction contract. */
  destroy(this: never): never;
  destroy(
    formData: Record<string, unknown>
  ): Promise<AdminUserDestroyResult | void>;

  destroy(
    formData?: Record<string, unknown>
  ): Promise<AdminUserDestroyResult | void> {
    return ajax(`/admin/users/${this.id}.json`, {
      type: "DELETE",
      data: formData,
    })
      .then((data: AdminUserDestroyResult) => {
        if (!data.deleted && data.user) {
          // TODO(typescript-pending): Ember's setProperties cannot infer subclass keys here; remove when it accepts partial base fields.
          this.setProperties(data.user as Partial<this>);
        }

        return data;
      })
      .catch(() => {
        // Instances have no `find`, so this rejects at runtime. TODO(typescript-pending): remove this cast with that runtime fix.
        (this as unknown as { find: typeof AdminUser.find })
          .find(this.id)
          .then((u) => this.setProperties(u as Partial<this>));
      });
  }

  merge(formData: {
    target_username: string;
    [key: string]: unknown;
  }): Promise<SuccessResponse> {
    return ajax(`/admin/users/${this.id}/merge.json`, {
      type: "POST",
      data: formData,
    });
  }

  async loadDetails(): Promise<AdminUser> {
    if (this.loadedDetails) {
      return this;
    }

    // Raw data preserves tracked values that are not enumerable on an AdminUser instance.
    const userProperties = await AdminUser.find(this.id, { raw: true });
    // TODO(typescript-pending): Ember's setProperties cannot infer subclass keys here; remove when it accepts partial base fields.
    this.setProperties(userProperties as Partial<this>);

    return this;
  }

  deleteSSORecord() {
    return ajax(`/admin/users/${this.id}/sso_record.json`, {
      type: "DELETE",
    })
      .then(() => {
        this.set("single_sign_on_record", null);
      })
      .catch(popupAjaxError);
  }
}

/** Legacy application global; declaring it preserves the module evaluation order. */
declare const moment: typeof import("moment");
