import { AUTO_GROUPS } from "discourse/lib/constants";

function chatAllowedGroups(siteSettings) {
  return (siteSettings.chat_allowed_groups || "")
    .toString()
    .split("|")
    .map((groupId) => parseInt(groupId, 10));
}

export function anonymousUserCanViewPublicChat(currentUser, siteSettings) {
  return (
    !currentUser &&
    siteSettings.enable_public_channels &&
    chatAllowedGroups(siteSettings).includes(AUTO_GROUPS.anonymous_users.id)
  );
}
