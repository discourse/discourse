import NotificationItemBase from "discourse/lib/notification-items/base";

import BookmarkReminder from "discourse/lib/notification-items/bookmark-reminder";
import Custom from "discourse/lib/notification-items/custom";
import GrantedBadge from "discourse/lib/notification-items/granted-badge";
import GroupMentioned from "discourse/lib/notification-items/group-mentioned";
import GroupMessageSummary from "discourse/lib/notification-items/group-message-summary";
import InviteeAccepted from "discourse/lib/notification-items/invitee-accepted";
import LikedConsolidated from "discourse/lib/notification-items/liked-consolidated";
import Liked from "discourse/lib/notification-items/liked";
import MembershipRequestAccepted from "discourse/lib/notification-items/membership-request-accepted";
import MembershipRequestConsolidated from "discourse/lib/notification-items/membership-request-consolidated";
import MovedPost from "discourse/lib/notification-items/moved-post";
import WatchingFirstPost from "discourse/lib/notification-items/watching-first-post";

const CLASS_FOR_TYPE = {
  bookmark_reminder: BookmarkReminder,
  custom: Custom,
  granted_badge: GrantedBadge,
  group_mentioned: GroupMentioned,
  group_message_summary: GroupMessageSummary,
  invitee_accepted: InviteeAccepted,
  liked: Liked,
  liked_consolidated: LikedConsolidated,
  membership_request_accepted: MembershipRequestAccepted,
  membership_request_consolidated: MembershipRequestConsolidated,
  moved_post: MovedPost,
  watching_first_post: WatchingFirstPost,
};

let _customClassForType = {};

export function registerNotificationTypeRenderer(notificationType, func) {
  _customClassForType[notificationType] = func(NotificationItemBase);
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
    _customClassForType[type] || CLASS_FOR_TYPE[type] || NotificationItemBase;
  return new klass({ notification, currentUser, siteSettings, site });
}
