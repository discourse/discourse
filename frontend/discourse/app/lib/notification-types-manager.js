import AdminProblems from "discourse/lib/notification-types/admin-problems";
import NotificationTypeBase from "discourse/lib/notification-types/base";
import BookmarkReminder from "discourse/lib/notification-types/bookmark-reminder";
import Custom from "discourse/lib/notification-types/custom";
import Edited from "discourse/lib/notification-types/edited";
import GrantedBadge from "discourse/lib/notification-types/granted-badge";
import GroupMentioned from "discourse/lib/notification-types/group-mentioned";
import GroupMessageSummary from "discourse/lib/notification-types/group-message-summary";
import InviteeAccepted from "discourse/lib/notification-types/invitee-accepted";
import Liked from "discourse/lib/notification-types/liked";
import LikedConsolidated from "discourse/lib/notification-types/liked-consolidated";
import LinkedConsolidated from "discourse/lib/notification-types/linked-consolidated";
import MembershipRequestAccepted from "discourse/lib/notification-types/membership-request-accepted";
import MembershipRequestConsolidated from "discourse/lib/notification-types/membership-request-consolidated";
import MovedPost from "discourse/lib/notification-types/moved-post";
import NewFeatures from "discourse/lib/notification-types/new-features";
import WatchingFirstPost from "discourse/lib/notification-types/watching-first-post";

const CLASS_FOR_TYPE = {
  bookmark_reminder: BookmarkReminder,
  custom: Custom,
  edited: Edited,
  granted_badge: GrantedBadge,
  group_mentioned: GroupMentioned,
  group_message_summary: GroupMessageSummary,
  invitee_accepted: InviteeAccepted,
  liked: Liked,
  liked_consolidated: LikedConsolidated,
  linked_consolidated: LinkedConsolidated,
  membership_request_accepted: MembershipRequestAccepted,
  membership_request_consolidated: MembershipRequestConsolidated,
  moved_post: MovedPost,
  new_features: NewFeatures,
  admin_problems: AdminProblems,
  watching_first_post: WatchingFirstPost,
};

let _customClassForType = {};

export function registerNotificationTypeRenderer(notificationType, func) {
  _customClassForType[notificationType] = func(NotificationTypeBase);
}

export function resetNotificationTypeRenderers() {
  _customClassForType = {};
}

export function getRenderDirector(
  type,
  notification,
  currentUser,
  siteSettings,
  site
) {
  const klass =
    _customClassForType[type] || CLASS_FOR_TYPE[type] || NotificationTypeBase;
  return new klass({ notification, currentUser, siteSettings, site });
}
