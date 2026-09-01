import { AUTO_GROUPS } from "discourse/lib/constants";

/**
 * Auto groups describing computed populations rather than stored membership.
 * Query access resolves against `group_ids`, so granting to one matches nobody.
 */
export const UNGRANTABLE_GROUP_IDS = [
  AUTO_GROUPS.everyone.id,
  AUTO_GROUPS.anonymous_users.id,
  AUTO_GROUPS.logged_in_users.id,
];
