import { expectTypeOf } from "expect-type";
import type AdminUser from "discourse/admin/models/admin-user";
import type Bookmark from "discourse/models/bookmark";
import type RestModel from "discourse/models/rest";
import type Topic from "discourse/models/topic";
import User, {
  SECOND_FACTOR_METHODS,
  type UserCreateAttrs,
  type UserFindDetailsOptions,
  type UserGroup,
  type UserOption,
  type UserStatus,
  type UserSummary,
} from "discourse/models/user";
import type UserActionStat from "discourse/models/user-action-stat";
import type UserDraftsStream from "discourse/models/user-drafts-stream";
import type {
  default as StoreService,
  ModelFor,
} from "discourse/services/store";

declare const store: StoreService;
declare const user: User;
declare const topic: Topic;
declare const stat: UserActionStat;
declare const admin: AdminUser;
declare const options: UserFindDetailsOptions;

expectTypeOf(user).toExtend<RestModel>();
expectTypeOf(user).not.toBeAny();
expectTypeOf<ModelFor<"user">>().toEqualTypeOf<User>();

/* Construction. */

// The current-user preload goes through the store with its groups and flags.
expectTypeOf(
  store.createRecord("user", {
    id: 1,
    username: "sam",
    isCurrent: true,
    groups: [{ id: 1, name: "staff", has_messages: true }],
  })
).toEqualTypeOf<User>();
// Routes and lookups create a user from its username alone.
expectTypeOf(User.create({ username: "sam" })).toEqualTypeOf<User>();
// A missing argument becomes an empty user.
expectTypeOf(User.create()).toEqualTypeOf<User>();
expectTypeOf(User.create(undefined)).toEqualTypeOf<User>();
// @ts-expect-error usernames are strings
User.create({ username: 1 });

expectTypeOf(User.current()).toEqualTypeOf<User | null>();
User.resetCurrent(null);
User.resetCurrent(user);

/* Identity: every server payload sends these; username-only users get them from `findDetails`. */

expectTypeOf(user.id).toEqualTypeOf<number>();
expectTypeOf(user.username).toEqualTypeOf<string>();
expectTypeOf(user.username_lower).toEqualTypeOf<string>();
expectTypeOf(user.avatar_template).toEqualTypeOf<string>();
// Omitted when names are disabled; null when the user has none.
expectTypeOf(user.name).toEqualTypeOf<string | null | undefined>();
expectTypeOf(user.title).toEqualTypeOf<string | null | undefined>();
// Embedded basic users omit roles and trust level.
expectTypeOf(user.admin).toEqualTypeOf<boolean | undefined>();
expectTypeOf(user.moderator).toEqualTypeOf<boolean | undefined>();
expectTypeOf(user.trust_level).toEqualTypeOf<number | undefined>();
expectTypeOf(user.primary_group_name).toEqualTypeOf<
  string | null | undefined
>();
expectTypeOf(user.flair_url).toEqualTypeOf<string | null | undefined>();
expectTypeOf(user.profile_hidden).toEqualTypeOf<true | undefined>();

/* Current-user payload. */

expectTypeOf(user.unread_notifications).toEqualTypeOf<number | undefined>();
expectTypeOf(user.grouped_unread_notifications).toEqualTypeOf<
  Record<string, number> | undefined
>();
expectTypeOf(user.can_send_private_messages).toEqualTypeOf<
  boolean | undefined
>();
// Sent only when true.
expectTypeOf(user.can_invite_to_forum).toEqualTypeOf<true | undefined>();
expectTypeOf(user.muted_category_ids).toEqualTypeOf<number[] | undefined>();
expectTypeOf(user.ignored_users).toEqualTypeOf<string[] | undefined>();
expectTypeOf(user.dismissed_banner_key).toEqualTypeOf<
  number | null | undefined
>();
expectTypeOf(user.do_not_disturb_until).toEqualTypeOf<
  string | null | undefined
>();

// Statuses expire at an ISO time or never; clearing one assigns null.
expectTypeOf(user.status).toEqualTypeOf<UserStatus | null | undefined>();
expectTypeOf<UserStatus["description"]>().toEqualTypeOf<string>();
expectTypeOf<UserStatus["emoji"]>().toEqualTypeOf<string>();
expectTypeOf<UserStatus["ends_at"]>().toEqualTypeOf<string | null>();
user.status = null;

/* Options: the current-user and profile serializers send different subsets. */

expectTypeOf(user.user_option).toEqualTypeOf<UserOption | undefined>();
expectTypeOf(user.user_option?.timezone).toEqualTypeOf<
  string | null | undefined
>();
expectTypeOf(user.user_option?.interface_color_mode).toEqualTypeOf<
  number | undefined
>();
expectTypeOf(user.user_option?.theme_ids).toEqualTypeOf<number[] | undefined>();
expectTypeOf(user.user_option?.seen_popups).toEqualTypeOf<
  number[] | null | undefined
>();

/* Derived state. */

expectTypeOf(user.staff).toEqualTypeOf<boolean | undefined>();
expectTypeOf(user.canManageTopic).toEqualTypeOf<boolean>();
expectTypeOf(user.canSetTopicTimer).toEqualTypeOf<boolean>();
expectTypeOf(user.isBasic).toEqualTypeOf<boolean>();
expectTypeOf(user.isLeader).toEqualTypeOf<boolean>();
expectTypeOf(user.displayName).toEqualTypeOf<string>();
expectTypeOf(user.adminPath).toEqualTypeOf<string>();
expectTypeOf(user.previousVisitAt).toEqualTypeOf<Date>();
expectTypeOf(user.suspendedForever).toEqualTypeOf<boolean>();
expectTypeOf(user.searchContext).toExtend<{
  type: string;
  id: string;
  user: User;
}>();
expectTypeOf(user.prefersDarkColor).toEqualTypeOf<boolean>();

/* Methods. */

expectTypeOf(user.findDetails()).resolves.toEqualTypeOf<User>();
expectTypeOf(
  user.findDetails({ forCard: true, include_post_count_for: 1 })
).resolves.toEqualTypeOf<User>();
expectTypeOf(
  User.findByUsername("sam", { forCard: true })
).resolves.toEqualTypeOf<User>();
User.findByUsername("sam");
user.findStaffInfo();
expectTypeOf(
  user.updateNotificationLevel({
    level: "ignore",
    expiringAt: "2026-10-27T10:00:00Z",
    actingUser: user,
  })
).resolves.toEqualTypeOf<void>();
user.updateNotificationLevel({ level: "normal", actingUser: user });
expectTypeOf(user.pmPath(topic)).toEqualTypeOf<string | undefined>();
expectTypeOf(user.isAllowedToUploadAFile("image")).toEqualTypeOf<boolean>();
expectTypeOf(user.inAllStream(stat)).toEqualTypeOf<boolean>();
expectTypeOf(user.isInDoNotDisturb()).toEqualTypeOf<boolean>();
expectTypeOf(user.dismissBanner(3)).toEqualTypeOf<void>();
user.updateDoNotDisturbStatus(null);
user.updateDoNotDisturbStatus("2026-10-27T10:00:00Z");
user.updateReviewableCount(3);
user.setPrimaryGroup(null);
user.setPrimaryGroup(1);
user.save();
user.save(["name", "title"]);
user.updateSecondFactor(0, "", true, SECOND_FACTOR_METHODS.BACKUP_CODE);
user.pickAvatar(1, "custom");

/* Statics. */

User.checkUsername("sam", undefined, 1);
// Username suggestions send no username.
User.checkUsername(null, "sam@example.com");
expectTypeOf(User.groupStats([stat])).toEqualTypeOf<UserActionStat[]>();

/* Status tracking and events. */

user.statusManager.trackStatus();
user.statusManager.stopTrackingStatus();
expectTypeOf(user.statusManager.isTrackingStatus()).toEqualTypeOf<boolean>();
const listener = { onStatusChanged() {} };
user.on("status-changed", listener, "onStatusChanged");
user.off("status-changed", listener, "onStatusChanged");
user.trigger("status-changed", user);

/* Construction from existing users and other spellings. */

expectTypeOf<UserCreateAttrs>().not.toBeAny();
expectTypeOf(User.create(user)).toEqualTypeOf<User>();
expectTypeOf(store.createRecord("user", user)).toEqualTypeOf<User>();
expectTypeOf(
  store.createRecord("User", { username: "sam" })
).toEqualTypeOf<User>();

/* Groups, child models and falsey getters. */

expectTypeOf(user.visibleGroups).toEqualTypeOf<UserGroup[] | undefined>();
expectTypeOf(user.groups).toEqualTypeOf<UserGroup[] | undefined>();
expectTypeOf(user.bookmarks).toEqualTypeOf<Bookmark>();
expectTypeOf(user.userDraftsStream).toEqualTypeOf<UserDraftsStream>();
// Absent timestamps pass through the `&&` unchanged.
expectTypeOf(user.suspended).toEqualTypeOf<"" | boolean | null | undefined>();
expectTypeOf(user.silenced).toEqualTypeOf<"" | boolean | null | undefined>();
expectTypeOf(user.path).toEqualTypeOf<string>();
expectTypeOf(user.sidebarLinkToFilteredList).toEqualTypeOf<
  boolean | undefined
>();
expectTypeOf(user.calculateMutedIds(0, 1, "muted_category_ids")).toEqualTypeOf<
  number[]
>();
expectTypeOf(user.findDetails(options)).resolves.toEqualTypeOf<User>();
// Notification tags arrive as records and are saved as names.
const notificationTags: NonNullable<User["watched_tags"]> = [
  { id: 1, name: "support", slug: "support" },
  "support",
];
expectTypeOf(notificationTags).not.toBeAny();

/* Summary: statistics are permission-gated independently of profile fields. */

expectTypeOf(user.summary()).resolves.toEqualTypeOf<UserSummary>();
expectTypeOf<UserSummary["likes_given"]>().toEqualTypeOf<number | undefined>();
expectTypeOf<UserSummary["bookmark_count"]>().toEqualTypeOf<
  number | undefined
>();
expectTypeOf<
  UserSummary["most_liked_users"][number]["count"]
>().toEqualTypeOf<number>();

/* Singleton and Evented returns. */

expectTypeOf(User.currentProp("username")).toEqualTypeOf<string | undefined>();
expectTypeOf(User.resetCurrent()).toEqualTypeOf<undefined>();
expectTypeOf(user.on("status-changed", () => {})).toEqualTypeOf<User>();
expectTypeOf(user.one("status-changed", () => {})).toEqualTypeOf<User>();
expectTypeOf(user.has("status-changed")).toEqualTypeOf<boolean>();

/* Subclasses: AdminUser's HTTP destroy stays compatible with the inherited one. */

expectTypeOf<AdminUser>().toExtend<User>();
expectTypeOf(admin.destroy({ deletePosts: true })).resolves.not.toBeAny();
