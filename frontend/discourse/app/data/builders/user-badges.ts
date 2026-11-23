import type { RpcRequest } from "discourse/data/builders/helpers";
import {
  createOne,
  deleteOne,
  readMany,
} from "discourse/data/builders/helpers";
import {
  normalizeUserBadgeRecordPayload,
  normalizeUserBadgesPayload,
} from "discourse/data/normalize";
import type { WarpResourceId } from "discourse/data/warp-rest-model";
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
  badgeId: WarpResourceId,
  opts: { limit?: number; offset?: number; username?: string | null } = {}
) {
  const url = applyQueryParams("/user_badges.json", {
    badge_id: badgeId,
    limit: opts.limit,
    offset: opts.offset,
    username: opts.username,
  });
  return readMany(url, normalizeUserBadgesPayload);
}

export function findUserBadgesByBadgeIds(
  badgeIds: WarpResourceId[],
  opts: {
    badgeTypeId?: WarpResourceId;
    offset?: number;
    username?: string | null;
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
  badgeId: WarpResourceId,
  username: string,
  reason?: string
) {
  return createOne(
    `/user_badges`,
    { username, badge_id: badgeId, reason },
    normalizeUserBadgeRecordPayload
  );
}

export function deleteUserBadge(id: WarpResourceId) {
  return deleteOne("user-badge", id, `/user_badges/${encodeURIComponent(id)}`);
}

// RPC-style: no `op` / `data` / normalizer.
export function toggleFavoriteUserBadge(id: WarpResourceId): RpcRequest {
  return {
    url: `/user_badges/${encodeURIComponent(id)}/toggle_favorite`,
    method: "PUT",
  };
}
