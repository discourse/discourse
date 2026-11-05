import type EmberObject from "@ember/object";
import { expectTypeOf } from "expect-type";
import type Category from "discourse/models/category";
import Invite, {
  type InviteCreateAttrs,
  type Invited,
} from "discourse/models/invite";
import Notification, {
  type NotificationData,
} from "discourse/models/notification";
import type RestModel from "discourse/models/rest";
import Reviewable, {
  APPROVED,
  DELETED,
  IGNORED,
  PENDING,
  REJECTED,
  type ReviewableClaim,
  type ReviewableFields,
  type ReviewableHistoryEntry,
  type ReviewablePayload,
  type ReviewableScore,
  type ReviewableWireFields,
} from "discourse/models/reviewable";
import type ReviewableHistory from "discourse/models/reviewable-history";
import type Topic from "discourse/models/topic";
import type User from "discourse/models/user";
import UserMenuReviewable from "discourse/models/user-menu-reviewable";
import type {
  default as StoreService,
  ModelFor,
  ResultSetOf,
} from "discourse/services/store";

declare const store: StoreService;
declare const user: User;

/* Notification: `/notifications`, user-menu lists and the notification bus. */

expectTypeOf<ModelFor<"notification">>().toEqualTypeOf<Notification>();
declare const notification: Notification;
expectTypeOf(notification).toExtend<RestModel>();
expectTypeOf(notification.id).toEqualTypeOf<number>();
expectTypeOf(notification.user_id).toEqualTypeOf<number>();
expectTypeOf(notification.notification_type).toEqualTypeOf<number>();
expectTypeOf(notification.read).toEqualTypeOf<boolean>();
expectTypeOf(notification.high_priority).toEqualTypeOf<boolean>();
expectTypeOf(notification.created_at).toEqualTypeOf<string>();
// Badge, group and admin notifications have no topic.
expectTypeOf(notification.topic_id).toEqualTypeOf<number | null>();
expectTypeOf(notification.post_number).toEqualTypeOf<number | null>();
expectTypeOf(notification.slug).toEqualTypeOf<string | null>();
expectTypeOf(notification.fancy_title).toEqualTypeOf<string | undefined>();
// Sent only when true.
expectTypeOf(notification.is_warning).toEqualTypeOf<boolean | undefined>();
// The data packet depends on the notification type and on plugins.
expectTypeOf(notification.data.display_username).toEqualTypeOf<
  string | undefined
>();
expectTypeOf(notification.data.topic_title).toEqualTypeOf<string | undefined>();
expectTypeOf(notification.data.revision_number).toEqualTypeOf<
  number | null | undefined
>();
expectTypeOf(notification.data.badge_id).toEqualTypeOf<number | undefined>();
expectTypeOf(notification.data["plugin_key"]).toEqualTypeOf<unknown>();
notification.read = true;
expectTypeOf(Notification.initializeNotifications([])).toEqualTypeOf<
  Promise<Notification[]>
>();
expectTypeOf(Notification.applyTransformations([notification])).toEqualTypeOf<
  Promise<void>
>();
expectTypeOf(
  store.find("notification", { username: "sam", limit: 30 })
).resolves.toEqualTypeOf<ResultSetOf<Notification> | undefined>();

/* UserMenuReviewable: the basic reviewable list in the user menu. */

const menuReviewable = UserMenuReviewable.create({
  id: 1,
  type: "ReviewableFlaggedPost",
  pending: true,
  created_at: "2026-10-27T23:51:37.081Z",
  flagger_username: "sam",
});
expectTypeOf(menuReviewable.id).toEqualTypeOf<number>();
expectTypeOf(menuReviewable.type).toEqualTypeOf<string>();
expectTypeOf(menuReviewable.pending).toEqualTypeOf<boolean>();
expectTypeOf(menuReviewable.created_at).toEqualTypeOf<string>();
// A deleted flagger serializes as null.
expectTypeOf(menuReviewable.flagger_username).toEqualTypeOf<string | null>();
// Each core type adds its own fields.
expectTypeOf(menuReviewable.post_number).toEqualTypeOf<number | undefined>();
expectTypeOf(menuReviewable.topic_fancy_title).toEqualTypeOf<
  string | undefined
>();
expectTypeOf(menuReviewable.is_new_topic).toEqualTypeOf<boolean | undefined>();
expectTypeOf(menuReviewable.payload_title).toEqualTypeOf<string | undefined>();
expectTypeOf(menuReviewable.username).toEqualTypeOf<string | undefined>();

/* Reviewable: the review queue and show page. */

expectTypeOf(PENDING).toEqualTypeOf<0>();
expectTypeOf(APPROVED).toEqualTypeOf<1>();
expectTypeOf(REJECTED).toEqualTypeOf<2>();
expectTypeOf(IGNORED).toEqualTypeOf<3>();
expectTypeOf(DELETED).toEqualTypeOf<4>();
expectTypeOf<ModelFor<"reviewable">>().toEqualTypeOf<Reviewable>();
expectTypeOf(store.find("reviewable", 1)).resolves.toEqualTypeOf<Reviewable>();
expectTypeOf(
  store.findAll("reviewable", { status: "pending", type: "ReviewableUser" })
).resolves.toEqualTypeOf<ResultSetOf<Reviewable> | undefined>();
declare const reviewable: Reviewable;
expectTypeOf(reviewable.id).toEqualTypeOf<number>();
expectTypeOf(reviewable.type).toEqualTypeOf<string>();
expectTypeOf(reviewable.status).toEqualTypeOf<number>();
expectTypeOf(reviewable.score).toEqualTypeOf<number>();
expectTypeOf(reviewable.version).toEqualTypeOf<number>();
expectTypeOf(reviewable.can_edit).toEqualTypeOf<boolean>();
expectTypeOf(reviewable.created_from_flag).toEqualTypeOf<boolean>();
// The store swaps side-loaded ids for records, or null when a record is missing.
expectTypeOf(reviewable.created_by).toEqualTypeOf<User | null>();
expectTypeOf(reviewable.topic).toEqualTypeOf<Topic | null | undefined>();
const history = reviewable.reviewable_histories[0];
expectTypeOf(history.reviewable_history_type).toEqualTypeOf<number>();
expectTypeOf(history.created_at).toEqualTypeOf<string>();
// Claiming appends a client-side entry that is not a model instance.
reviewable.reviewable_histories = [
  ...reviewable.reviewable_histories,
  {
    reviewable_history_type: 3,
    created_at: "2026-10-27T23:51:37.081Z",
    created_by: user,
  },
];
declare const serverHistory: ReviewableHistory;
reviewable.reviewable_histories = [serverHistory];
expectTypeOf(reviewable.category).toEqualTypeOf<Category | undefined>();
expectTypeOf(reviewable.resolvedType).toEqualTypeOf<string>();
expectTypeOf(reviewable.humanType).toEqualTypeOf<string>();
expectTypeOf(reviewable.userReviewableContextQuestion).toEqualTypeOf<
  string | null
>();
// Queued posts carry their composer state in a whitelisted payload.
expectTypeOf(reviewable.payload).not.toBeAny();
reviewable.last_performing_username = null;
expectTypeOf(reviewable.update({ payload: { raw: "Edited" } })).toExtend<
  PromiseLike<void>
>();

/* Invite: `/u/:username/invited.json` and the invite modals. */

const invite = Invite.create();
expectTypeOf(invite).toEqualTypeOf<Invite>();
expectTypeOf(invite).toExtend<EmberObject>();
// Pending entries.
expectTypeOf(invite.id).toEqualTypeOf<number | undefined>();
expectTypeOf(invite.invite_key).toEqualTypeOf<string | undefined>();
expectTypeOf(invite.email).toEqualTypeOf<string | null | undefined>();
expectTypeOf(invite.domain).toEqualTypeOf<string | null | undefined>();
expectTypeOf(invite.expired).toEqualTypeOf<boolean | undefined>();
// Redeemed entries.
expectTypeOf(invite.redeemed_at).toEqualTypeOf<string | undefined>();
expectTypeOf(invite.user).toEqualTypeOf<User | undefined>();
expectTypeOf(invite.groupIds).toEqualTypeOf<number[]>();
expectTypeOf(invite.topic).toEqualTypeOf<Topic | null>();
expectTypeOf(invite.topicId).toEqualTypeOf<number | undefined>();
invite.topicId = 5;
invite.save({ email: "new@example.com", topic_id: 5 });
invite.destroy();
invite.reinvite();
declare const invited: Awaited<ReturnType<typeof Invite.findInvitedBy>>;
Invite.findInvitedBy(user, "pending");
expectTypeOf(invited?.invites).toEqualTypeOf<Invite[] | undefined>();
expectTypeOf(invited?.can_see_invite_details).toEqualTypeOf<
  boolean | undefined
>();
expectTypeOf(invited?.counts.redeemed).toEqualTypeOf<number | undefined>();
Invite.findInvitedBy(user, "pending", "term", 30);
Invite.destroyAllExpired(user);
Invite.reinviteAll();

/* Registry spellings, open packets and wire shapes. */

expectTypeOf<ModelFor<"Notification">>().toEqualTypeOf<Notification>();
expectTypeOf<ModelFor<"Reviewable">>().toEqualTypeOf<Reviewable>();
expectTypeOf<NotificationData["custom_key"]>().toBeUnknown();
// Plugin-only top-level fields stay out of core.
expectTypeOf<Notification>().not.toHaveProperty("topic_bumped_at");
expectTypeOf<ReviewableFields>().not.toHaveProperty("chat_channel");
// munge strips `category` so the getter wins.
expectTypeOf<ReviewableFields>().not.toHaveProperty("category");
expectTypeOf<ReviewablePayload["custom_key"]>().toBeUnknown();
expectTypeOf<ReviewablePayload["tags"]>().toEqualTypeOf<
  string[] | null | undefined
>();
expectTypeOf(reviewable.claimed_by).toEqualTypeOf<
  ReviewableClaim | null | undefined
>();
// Claims arriving over the message bus are plain objects.
reviewable.claimed_by = { user, automatic: false };
reviewable.claimed_by = null;
expectTypeOf<ReviewableWireFields["created_by_id"]>().toEqualTypeOf<number>();
expectTypeOf<ReviewableWireFields>().not.toHaveProperty("created_by");
expectTypeOf<ReviewableScore["score_type"]>().toBeNullable();
expectTypeOf<ReviewableHistoryEntry>().not.toExtend<EmberObject>();
expectTypeOf(
  reviewable.update({ payload: { raw: "Edited", extra: true } })
).resolves.toBeVoid();
// update reads the keys of its argument, so it needs one.
// @ts-expect-error updates are required
reviewable.update();

const genericMenuItem = UserMenuReviewable.create({
  id: 1,
  type: "ExtensionType",
  pending: true,
  created_at: "2026-10-27T23:51:37.081Z",
  flagger_username: null,
});
expectTypeOf(genericMenuItem.type).toEqualTypeOf<string>();

const pending = Invite.create({ email: null, domain: null, topics: [] });
const redeemed = Invite.create({
  redeemed_at: "2026-10-27T23:51:37.081Z",
  user: { id: 1, username: "sam", name: null, avatar_template: "/avatar.png" },
});
expectTypeOf(redeemed.user).toEqualTypeOf<User | undefined>();
expectTypeOf(pending.shortKey).toEqualTypeOf<string>();
expectTypeOf(pending.destroy()).resolves.toBeBoolean();
expectTypeOf<Invited>().toExtend<EmberObject>();
expectTypeOf<InviteCreateAttrs>().not.toBeAny();

class ExtendedInvite extends Invite {
  declare extension_field: string;
}
expectTypeOf(
  ExtendedInvite.create({ extension_field: "value" })
).toEqualTypeOf<ExtendedInvite>();
