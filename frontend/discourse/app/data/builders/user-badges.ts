import {
  createOne,
  deleteOne,
  readMany,
} from "discourse/data/builders/helpers";
import {
  normalizeUserBadgeRecordPayload,
  normalizeUserBadgesPayload,
} from "discourse/data/normalize";
import type { WarpRequest } from "discourse/data/warp-rest-model";
import { applyQueryParams } from "discourse/lib/url";

// `/user-badges/:username` (dashed) and `/user_badges` (underscored) are
// distinct Rails routes — not a typo.

export function findUserBadgesByUsername(
  username: string,
  opts: { grouped?: boolean } = {}
) {
  const url = applyQueryParams(
    `/user-badges/${encodeURIComponent(username)}.json`,
    { grouped: opts.grouped ? "true" : null }
  );
  return readMany(url, normalizeUserBadgesPayload);
}

export function findUserBadgesByBadgeId(
  badgeId: string | number,
  opts: { offset?: number; username?: string } = {}
) {
  const url = applyQueryParams("/user_badges.json", {
    badge_id: badgeId,
    offset: opts.offset,
    username: opts.username,
  });
  return readMany(url, normalizeUserBadgesPayload);
}

export function findUserBadgesByBadgeIds(
  badgeIds: Array<string | number>,
  opts: {
    badgeTypeId?: string | number;
    offset?: number;
    username?: string;
    limit?: number;
  } = {}
) {
  const url = applyQueryParams("/user_badges.json", {
    badge_ids: badgeIds.length ? badgeIds.join(",") : null,
    badge_type_id: opts.badgeTypeId,
    offset: opts.offset,
    username: opts.username,
    limit: opts.limit,
  });
  return readMany(url, normalizeUserBadgesPayload);
}

export function grantUserBadge(
  badgeId: string | number,
  username: string,
  reason?: string
) {
  return createOne(
    `/user_badges`,
    { username, badge_id: badgeId, reason },
    normalizeUserBadgeRecordPayload
  );
}

export function deleteUserBadge(id: string | number) {
  return deleteOne("user-badge", id, `/user_badges/${encodeURIComponent(id)}`);
}

// RPC-style: no `op` / `data` / normalizer.
export function toggleFavoriteUserBadge(id: string | number): WarpRequest {
  return {
    url: `/user_badges/${encodeURIComponent(id)}/toggle_favorite`,
    method: "PUT",
  };
}
