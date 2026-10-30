import type EmberObject from "@ember/object";
import { expectTypeOf } from "expect-type";
import AdminUser, {
  type AdminUserDetails,
  type AdminUserFields,
  type AdminUserGroup,
} from "discourse/admin/models/admin-user";
import ApiKey, { type ApiKeyFields } from "discourse/admin/models/api-key";
import EmailLog from "discourse/admin/models/email-log";
import IncomingEmail, {
  type IncomingEmailDetails,
} from "discourse/admin/models/incoming-email";
import StaffActionLog, {
  type StaffActionValue,
} from "discourse/admin/models/staff-action-log";
import Tl3Requirements, {
  type Tl3RequirementsFields,
} from "discourse/admin/models/tl3-requirements";
import WebHook, {
  type WebHookCategory,
  type WebHookEventType,
} from "discourse/admin/models/web-hook";
import type { BehaviorTransformerResult } from "discourse/lib/transformer";
import type RestModel from "discourse/models/rest";
import type User from "discourse/models/user";
import type {
  default as StoreService,
  ModelCreateAttrsFor,
  ModelFor,
  ResultSetOf,
} from "discourse/services/store";

declare const store: StoreService;

/* Store registrations, under every spelling callers use. */

expectTypeOf<ModelFor<"api-key">>().toEqualTypeOf<ApiKey>();
expectTypeOf<ModelFor<"web-hook">>().toEqualTypeOf<WebHook>();
expectTypeOf<ModelFor<"staff-action-log">>().toEqualTypeOf<StaffActionLog>();
expectTypeOf<ModelFor<"tl3Requirements">>().toEqualTypeOf<Tl3Requirements>();
expectTypeOf<ModelFor<"tl3-requirements">>().toEqualTypeOf<Tl3Requirements>();
expectTypeOf(store.findAll("api-key")).resolves.toEqualTypeOf<
  ResultSetOf<ApiKey> | undefined
>();
expectTypeOf(store.find("web-hook", 1)).resolves.toEqualTypeOf<WebHook>();
store.createRecord("web-hook");
store
  .createRecord("api-key")
  .save({ description: "New", scope_mode: "global" });

/* AdminUser: `/admin/users/:id` details and `/admin/users/list` rows. */

expectTypeOf(AdminUser.find(1)).resolves.toEqualTypeOf<AdminUser>();
expectTypeOf(
  AdminUser.find("1", { raw: false })
).resolves.toEqualTypeOf<AdminUser>();
// Raw lookups return the response for `setProperties`, not an instance.
expectTypeOf(
  AdminUser.find(1, { raw: true })
).resolves.not.toExtend<AdminUser>();
expectTypeOf(AdminUser.find(1, { raw: true })).resolves.toHaveProperty(
  "loadedDetails"
);
expectTypeOf(
  AdminUser.findAll("active", { filter: "bruce", show_emails: true, page: 2 })
).resolves.toEqualTypeOf<AdminUser[]>();
// Embedded basic users become partial instances.
AdminUser.create({
  id: 1,
  username: "anne",
  name: null,
  avatar_template: "/a.png",
});

declare const admin: AdminUser;
expectTypeOf(admin).toExtend<User>();
expectTypeOf(admin.adminUserView).toEqualTypeOf<boolean>();
expectTypeOf(admin.last_seen_at).toEqualTypeOf<string | null | undefined>();
expectTypeOf(admin.last_emailed_at).toEqualTypeOf<string | null | undefined>();
expectTypeOf(admin.last_seen_age).toEqualTypeOf<number | null | undefined>();
expectTypeOf(admin.manual_locked_trust_level).toEqualTypeOf<
  number | null | undefined
>();
expectTypeOf(admin.secondary_emails).toEqualTypeOf<string[] | undefined>();
// List rows omit the detail fields, and details omit the list capabilities.
expectTypeOf(admin.can_be_suspended).toEqualTypeOf<boolean | undefined>();
expectTypeOf(admin.bounce_score).toEqualTypeOf<number | undefined>();
expectTypeOf(admin.reset_bounce_score_after).toEqualTypeOf<
  string | null | undefined
>();
expectTypeOf(admin.full_suspend_reason).toEqualTypeOf<
  string | null | undefined
>();
expectTypeOf(admin.next_penalty).toEqualTypeOf<string | null | undefined>();
// The top-level counts have no total; the TL3 counts do.
expectTypeOf(admin.penalty_counts).toEqualTypeOf<
  { silenced: number; suspended: number } | undefined
>();
expectTypeOf(admin.suspended_by?.username).toEqualTypeOf<string | undefined>();
expectTypeOf(admin.single_sign_on_record?.external_id).not.toBeAny();
expectTypeOf(admin.upcoming_changes_stats?.[0].enabled).not.toBeAny();
expectTypeOf(admin.tl3_requirements?.requirements_met).toEqualTypeOf<
  boolean | undefined
>();
expectTypeOf(admin.can_grant_admin).toEqualTypeOf<boolean | undefined>();
expectTypeOf(admin.api_key_count).toEqualTypeOf<number | undefined>();
// The admin template edits these in place.
admin.trust_level = 2;
admin.primary_group_id = null;
admin.set("can_activate", false);

expectTypeOf(admin.canViewProfile).toEqualTypeOf<boolean | undefined>();
expectTypeOf(admin.canResetBounceScore).toEqualTypeOf<boolean>();
expectTypeOf(admin.dirty).toEqualTypeOf<boolean>();
expectTypeOf(admin.canLockTrustLevel).toEqualTypeOf<boolean>();
expectTypeOf(admin.canSuspend).toEqualTypeOf<boolean>();
expectTypeOf(admin.canSilence).toEqualTypeOf<boolean>();
expectTypeOf(admin.customGroups).not.toBeAny();
expectTypeOf(admin.automaticGroups).toEqualTypeOf<typeof admin.customGroups>();
expectTypeOf(admin.bounceScore).toEqualTypeOf<string | number | undefined>();
expectTypeOf(admin.bounceScoreExplanation).toEqualTypeOf<string>();
expectTypeOf(admin.bounceLink).toEqualTypeOf<string>();
expectTypeOf(admin.suspendDuration).toEqualTypeOf<string>();
expectTypeOf(admin.tl3Requirements).toEqualTypeOf<
  Tl3Requirements | undefined
>();
expectTypeOf(admin.suspendedBy).toEqualTypeOf<AdminUser | null>();
expectTypeOf(admin.silencedBy).toEqualTypeOf<AdminUser | null>();
expectTypeOf(admin.approvedBy).toEqualTypeOf<AdminUser | null>();

expectTypeOf(admin.loadDetails()).resolves.toEqualTypeOf<AdminUser>();
// Some callers grant admin without form data.
admin.grantAdmin();
admin.grantAdmin({ email_confirmation_token: "abc" });
admin.lockTrustLevel(true);
admin.groupRemoved(5);
admin.suspend({
  suspend_until: "2027-01-01",
  reason: "Bad",
  message: "msg",
  post_id: 3,
});
admin.silence({ silenced_till: "2027-01-01", reason: "Noisy" });
admin.destroy({ deletePosts: true, block_email: true });
admin.merge({ target_username: "bruce" });

/* Tl3Requirements: embedded in details for TL2 and above. */

declare const tl3: Tl3Requirements;
expectTypeOf(tl3).toExtend<EmberObject>();
expectTypeOf(tl3.time_period).toEqualTypeOf<number>();
expectTypeOf(tl3.min_likes_received_users).toEqualTypeOf<number>();
expectTypeOf(tl3.requirements_lost).toEqualTypeOf<boolean>();
expectTypeOf(tl3.on_grace_period).toEqualTypeOf<boolean>();
expectTypeOf(tl3.penalty_counts).toEqualTypeOf<{
  silenced: number;
  suspended: number;
  total: number;
}>();
expectTypeOf(tl3.days_visited_percent).toEqualTypeOf<number>();
expectTypeOf(tl3.capped_topics_replied_to).toEqualTypeOf<boolean>();
expectTypeOf(tl3.met.likes_received_days).toEqualTypeOf<boolean>();
expectTypeOf(tl3.met.level_locked).toEqualTypeOf<boolean>();
expectTypeOf(tl3.met.suspended).toEqualTypeOf<boolean>();

/* ApiKey: `/admin/api/keys` list rows and detail records. */

declare const apiKey: ApiKey;
expectTypeOf(apiKey).toExtend<RestModel>();
expectTypeOf(apiKey.id).toEqualTypeOf<number>();
expectTypeOf(apiKey.truncated_key).toEqualTypeOf<string>();
expectTypeOf(apiKey.scope_mode).toEqualTypeOf<
  "global" | "read_only" | "granular" | null
>();
expectTypeOf(apiKey.last_used_at).toEqualTypeOf<string | null>();
expectTypeOf(apiKey.revoked_at).toEqualTypeOf<string | null>();
// Only detail records carry scopes, and only new keys carry the full key.
expectTypeOf(apiKey.updated_at).toEqualTypeOf<string | undefined>();
expectTypeOf(apiKey.key).toEqualTypeOf<string | undefined>();
expectTypeOf(apiKey.api_key_scopes?.[0].allowed_parameters).toEqualTypeOf<
  Record<string, string[]> | null | undefined
>();
expectTypeOf(apiKey.api_key_scopes?.[0].urls).toEqualTypeOf<
  string[] | undefined
>();
expectTypeOf(apiKey.user).toEqualTypeOf<AdminUser | null | undefined>();
expectTypeOf(apiKey.createdBy).toEqualTypeOf<AdminUser | null | undefined>();
// The setters wrap raw basic users.
apiKey.user = { id: 1, username: "anne", avatar_template: "/a.png" };
apiKey.created_by = null;
apiKey.description = "Renamed";
expectTypeOf<ApiKey["description"]>().toEqualTypeOf<string | null>();
expectTypeOf(apiKey.truncatedKey).toEqualTypeOf<string>();
expectTypeOf(apiKey.shortDescription).toEqualTypeOf<string | null>();
expectTypeOf(apiKey.basePath).toEqualTypeOf<string>();
expectTypeOf(apiKey.revoke()).not.toBeAny();
expectTypeOf(apiKey.createProperties()).not.toBeAny();

/* EmailLog: sent, bounced and skipped rows. */

expectTypeOf(
  EmailLog.findAll({ status: "skipped", address: "a@example.com" }, 50)
).resolves.toEqualTypeOf<EmailLog[]>();
EmailLog.findAll();
EmailLog.create();
EmailLog.create({
  id: 249,
  to_address: "a@example.com",
  email_type: "signup",
  user_id: 1,
  created_at: "2026-10-28T00:44:19.980Z",
  cc_addresses: null,
  post_id: null,
  bounced: true,
  has_bounce_key: true,
  smtp_transaction_response: null,
  user: { id: 1, username: "bruce", name: null, avatar_template: "/a.png" },
});
EmailLog.create({
  id: 16,
  to_address: "x@example.com",
  email_type: "invite",
  user_id: null,
  created_at: "2026-10-28T00:44:19.979Z",
  skipped_reason: "Custom reason",
  user: null,
});

declare const emailLog: EmailLog;
expectTypeOf(emailLog).toExtend<EmberObject>();
expectTypeOf(emailLog.user).toEqualTypeOf<AdminUser | null>();
expectTypeOf(emailLog.user_id).toEqualTypeOf<number | null>();
expectTypeOf(emailLog.cc_addresses).toEqualTypeOf<
  string[] | null | undefined
>();
expectTypeOf(emailLog.skipped_reason).toEqualTypeOf<string | undefined>();
expectTypeOf(emailLog.reply_key).toEqualTypeOf<string | undefined>();
expectTypeOf(emailLog.post_url).toEqualTypeOf<string | undefined>();

/* IncomingEmail: received and rejected rows, plus the raw detail lookups. */

expectTypeOf(
  IncomingEmail.findAll({ status: "rejected" }, 0)
).resolves.toEqualTypeOf<IncomingEmail[]>();
expectTypeOf(IncomingEmail.find(1)).resolves.not.toExtend<IncomingEmail>();
expectTypeOf(IncomingEmail.find(1)).resolves.toEqualTypeOf<
  Awaited<ReturnType<typeof IncomingEmail.findByBounced>>
>();
expectTypeOf(IncomingEmail.find(1)).resolves.toHaveProperty("headers");
IncomingEmail.create({
  id: 302,
  created_at: "2026-10-28T00:44:19.984Z",
  from_address: "foo@example.com",
  to_addresses: ["someone@else.com"],
  cc_addresses: null,
  subject: "Hello",
  error: "Email::Receiver::BadDestinationAddress",
  user: null,
});

declare const incoming: IncomingEmail;
expectTypeOf(incoming.to_addresses).toEqualTypeOf<string[] | null>();
expectTypeOf(incoming.error).toEqualTypeOf<string | undefined>();
expectTypeOf(incoming.user).toEqualTypeOf<AdminUser | null>();

/* StaffActionLog: `/admin/logs/staff_action_logs` rows. */

declare const log: StaffActionLog;
expectTypeOf(log).toExtend<RestModel>();
expectTypeOf(log.action_name).toEqualTypeOf<string>();
expectTypeOf(log.action).toEqualTypeOf<number>();
expectTypeOf(log.details).toEqualTypeOf<string | null>();
expectTypeOf(log.custom_type).toEqualTypeOf<string | null>();
expectTypeOf(log.expires_at).toEqualTypeOf<string | null>();
expectTypeOf(log.reviewable_id).toEqualTypeOf<number | undefined>();
expectTypeOf(log.acting_user).toEqualTypeOf<AdminUser | null>();
expectTypeOf(log.target_user).toEqualTypeOf<AdminUser | null>();
// Theme and tag group changes send parsed JSON; other actions send strings.
log.new_value = { name: "Cool theme" };
log.previous_value = "Old";
log.new_value = null;
expectTypeOf(log.showFullDetails).toEqualTypeOf<boolean>();
expectTypeOf(log.actionName).toEqualTypeOf<string>();
expectTypeOf(log.formattedDetails).toEqualTypeOf<string>();
expectTypeOf(log.useCustomModalForDetails).toEqualTypeOf<boolean>();
expectTypeOf(log.useModalForDetails).not.toBeAny();
expectTypeOf<boolean>().toExtend<typeof log.useModalForDetails>();
expectTypeOf(
  StaffActionLog.findAll({ action_name: "x" })
).resolves.toHaveProperty("staff_action_logs");

/* WebHook: `/admin/api/web_hooks` records and their extras. */

declare const webHook: WebHook;
expectTypeOf(webHook).toExtend<RestModel>();
expectTypeOf(webHook.payload_url).toEqualTypeOf<string>();
expectTypeOf(webHook.content_type).toEqualTypeOf<number>();
expectTypeOf(webHook.last_delivery_status).toEqualTypeOf<number>();
expectTypeOf(webHook.secret).toEqualTypeOf<string | null>();
expectTypeOf(webHook.category_ids).toEqualTypeOf<number[]>();
expectTypeOf(webHook.group_ids).toEqualTypeOf<number[]>();
expectTypeOf(webHook.web_hook_event_types?.[0].group).toEqualTypeOf<
  string | null | undefined
>();
// The group selector stores a comma-separated string.
webHook.group_names = "staff,admins";
webHook.group_names = ["staff"];
webHook.group_names = null;
// Tag selectors store names alongside serialized tags.
webHook.tags = ["tag1", { id: 1, name: "tag2", slug: "tag2" }];
expectTypeOf(webHook.wildcard).toEqualTypeOf<"wildcard" | "individual">();
webHook.wildcard = "individual";
expectTypeOf(webHook.description).toEqualTypeOf<string>();
expectTypeOf(webHook.categories).not.toBeAny();
expectTypeOf(webHook.groupFinder("staff")).not.toBeAny();
expectTypeOf(webHook.createProperties().web_hook_event_type_ids).toEqualTypeOf<
  (number | null)[]
>();
expectTypeOf(webHook.updateProperties()).toEqualTypeOf<
  ReturnType<typeof webHook.createProperties>
>();
const extras = new WebHook.ExtrasClass({
  content_types: [{ id: 1, name: "application/json" }],
  delivery_statuses: [{ id: 1, name: "inactive" }],
});
expectTypeOf(extras.findCategoryById(1)).not.toBeAny();
expectTypeOf(extras.grouped_event_types).not.toBeAny();

/* Raw lookups, subclass factories and store creation. */

declare const raw: boolean;

expectTypeOf(AdminUser.find(1, { raw })).resolves.toEqualTypeOf<
  AdminUser | AdminUserDetails
>();
expectTypeOf(AdminUser.find(1, null)).resolves.toEqualTypeOf<AdminUser>();
expectTypeOf(AdminUser.find(1, { raw: true })).resolves.not.toHaveProperty(
  "destroy"
);
expectTypeOf(AdminUser.find(1, { raw: true }))
  .resolves.toHaveProperty("secondary_emails")
  .toEqualTypeOf<string[] | undefined>();
expectTypeOf(AdminUser.find(1, { raw: true }))
  .resolves.toHaveProperty("associated_accounts")
  .toEqualTypeOf<User["associated_accounts"]>();
expectTypeOf<"canViewProfile">().not.toExtend<keyof AdminUserFields>();
expectTypeOf<"user">().not.toExtend<keyof ApiKeyFields>();

class PluginAdminUser extends AdminUser {
  declare pluginValue?: string;
  declare trust_level: 2;
  declare visibleGroups: AdminUserGroup[] | undefined;
}

class PluginApiKey extends ApiKey {
  declare pluginValue?: string;
}

class PluginStaffActionLog extends StaffActionLog {
  declare pluginValue?: string;
}

class PluginWebHook extends WebHook {
  declare pluginValue?: string;
}

class PluginEmailLog extends EmailLog {
  declare pluginValue?: string;
}

class PluginIncomingEmail extends IncomingEmail {
  declare pluginValue?: string;
}

expectTypeOf(
  PluginAdminUser.create({ pluginValue: "x" })
).toEqualTypeOf<PluginAdminUser>();
expectTypeOf(
  PluginApiKey.create({ pluginValue: "x" })
).toEqualTypeOf<PluginApiKey>();
expectTypeOf(
  PluginStaffActionLog.create({ pluginValue: "x" })
).toEqualTypeOf<PluginStaffActionLog>();
expectTypeOf(
  PluginEmailLog.create({ pluginValue: "x" })
).toEqualTypeOf<PluginEmailLog>();
expectTypeOf(
  PluginIncomingEmail.create({ pluginValue: "x" })
).toEqualTypeOf<PluginIncomingEmail>();
// Web hooks sideload their categories through the basic category serializer.
const webHookCategory = {
  id: 1,
  name: "Support",
  slug: "support",
  color: "0088CC",
  text_color: "FFFFFF",
  style_type: "square",
  icon: null,
  emoji: null,
  read_restricted: false,
} as const;
expectTypeOf(
  PluginWebHook.create({
    pluginValue: "x",
    categories: [webHookCategory],
  })
).toEqualTypeOf<PluginWebHook>();
expectTypeOf<typeof WebHook>().toExtend<typeof RestModel>();
expectTypeOf<typeof PluginAdminUser>().toExtend<typeof User>();
expectTypeOf<typeof EmailLog>().toExtend<typeof EmberObject>();
expectTypeOf<typeof IncomingEmail>().toExtend<typeof EmberObject>();
expectTypeOf<typeof ApiKey>().toExtend<typeof RestModel>();
expectTypeOf<typeof StaffActionLog>().toExtend<typeof RestModel>();

const basic = { id: 1, username: "anne", avatar_template: "/a.png" };
store.createRecord("apiKey", { user: basic, created_by: basic });
store.createRecord("staff-action-log", {
  acting_user: basic,
  target_user: null,
});
expectTypeOf(
  store.createRecord("email-log", { user: basic })
).toEqualTypeOf<EmailLog>();
expectTypeOf<ModelCreateAttrsFor<"tl3Requirements">>().toEqualTypeOf<
  Partial<Tl3RequirementsFields>
>();
expectTypeOf(
  store.createRecord("tl3Requirements", { requirements_met: true })
).toEqualTypeOf<Tl3Requirements>();
apiKey.user = null;
apiKey.created_by = basic;
expectTypeOf<"created_by">().not.toExtend<keyof ApiKeyFields>();
expectTypeOf(apiKey.createdBy).toEqualTypeOf<AdminUser | null | undefined>();

expectTypeOf(admin.unsuspend()).toEqualTypeOf<
  BehaviorTransformerResult<ReturnType<AdminUser["suspend"]>>
>();
expectTypeOf(admin.unsilence()).toEqualTypeOf<
  BehaviorTransformerResult<Promise<void>>
>();
expectTypeOf(admin.sendActivationEmail()).resolves.toEqualTypeOf<unknown>();
expectTypeOf(admin.deleteAllPosts()).resolves.toEqualTypeOf<{
  posts_deleted: number;
}>();
expectTypeOf(admin.deleteAllPostsDecider()).resolves.toEqualTypeOf<{
  job_enqueued: boolean;
  post_count: number;
}>();

expectTypeOf(
  IncomingEmail.findByBounced(1)
).resolves.toEqualTypeOf<IncomingEmailDetails>();
expectTypeOf<IncomingEmailDetails>().not.toHaveProperty("id");
expectTypeOf<IncomingEmailDetails>().not.toHaveProperty("user");
expectTypeOf(StaffActionLog.findAll())
  .resolves.toHaveProperty("user_history_actions")
  .toEqualTypeOf<{ id: string; action_id: number }[] | undefined>();

expectTypeOf(webHook.categories).toEqualTypeOf<
  (WebHookCategory | undefined)[]
>();
expectTypeOf<ModelCreateAttrsFor<"web-hook">["categories"]>().toEqualTypeOf<
  WebHookCategory[] | undefined
>();
webHook.categories = [webHookCategory];
// @ts-expect-error an id and a name are not a saved category
webHook.categories = [{ id: 1, name: "Support" }];
webHook.tags = [1, "support", { id: 2, name: "help", slug: "help" }];
const emptyExtras = new WebHook.ExtrasClass({ categories: null });
expectTypeOf(emptyExtras.findCategoryById(1)).toEqualTypeOf<
  WebHookCategory | undefined
>();
expectTypeOf(emptyExtras.grouped_event_types).toEqualTypeOf<
  Record<string, WebHookEventType[]> | []
>();

// New records from the store start empty.
expectTypeOf<ApiKey["created_at"]>().toEqualTypeOf<string | undefined>();
expectTypeOf<EmailLog["id"]>().toEqualTypeOf<number | undefined>();
expectTypeOf<EmailLog["to_address"]>().toEqualTypeOf<string | undefined>();
expectTypeOf<IncomingEmail["cc_addresses"]>().toEqualTypeOf<
  string[] | null | undefined
>();
expectTypeOf<StaffActionLog["new_value"]>().toEqualTypeOf<
  StaffActionValue | undefined
>();
expectTypeOf<WebHook["id"]>().toEqualTypeOf<number | undefined>();
expectTypeOf<WebHook["extras"]>().toEqualTypeOf<
  InstanceType<typeof WebHook.ExtrasClass> | undefined
>();
