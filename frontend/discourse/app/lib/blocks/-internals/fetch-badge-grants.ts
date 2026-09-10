import { ajax } from "discourse/lib/ajax";
import UserBadge from "discourse/models/user-badge";

/**
 * A single badge grant projected for card rendering: the recipient, the badge
 * they earned, and when it was granted. `user` and `badge` are the live
 * Discourse models (loosely typed here — the untyped models predate strict
 * typing), enough for the avatar/link and badge button to consume.
 */
export interface BadgeGrant {
  id: number;
  user: { username: string; [key: string]: unknown };
  badge: object;
  grantedAt: number;
}

/**
 * Parameters for {@link fetchBadgeGrants}.
 */
export interface BadgeGrantsParams {
  /** Pipe-separated badge IDs, e.g. `"24|10|45"`. */
  badgeIds?: string;
  /** Only include grants from the last N days; `0`/undefined means no window. */
  maxDays?: number;
  /** Maximum number of recipients to return. */
  count?: number;
}

/**
 * Resolves the most recent recipients of the given badges, newest grant first.
 * Hits the public `/user_badges/featured.json` endpoint and stitches the
 * side-loaded users/badges via `UserBadge.createFromJson`. Returns `null` when
 * no badges are configured or nothing has been granted (drives the block's
 * empty state); a failed request throws (drives the error state).
 *
 * @param params - The badges, recency window, and recipient count to fetch.
 * @returns The resolved grants, or `null` when there is nothing to show.
 */
export async function fetchBadgeGrants({
  badgeIds,
  maxDays,
  count,
}: BadgeGrantsParams): Promise<BadgeGrant[] | null> {
  const ids = (badgeIds ?? "").split("|").filter(Boolean);
  if (!ids.length) {
    return null;
  }

  const response = await ajax("/user_badges/featured.json", {
    data: { badge_ids: ids.join("|"), max_days: maxDays, limit: count },
  });

  const grants = UserBadge.createFromJson(response) as unknown as BadgeGrant[];
  return grants.length ? grants : null;
}
