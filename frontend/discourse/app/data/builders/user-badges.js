import {
  buildQuery,
  createOne,
  deleteOne,
  readMany,
} from "discourse/data/builders/helpers";
import {
  normalizeUserBadgeRecordPayload,
  normalizeUserBadgesPayload,
} from "discourse/data/normalize";

// `/user-badges/:username` (dashed) and `/user_badges` (underscored) are
// distinct Rails routes — not a typo.

export function findUserBadgesByUsername(username, opts = {}) {
  const query = buildQuery({ grouped: opts.grouped ? "true" : null });
  return readMany(
    `/user-badges/${encodeURIComponent(username)}.json${query}`,
    normalizeUserBadgesPayload
  );
}

export function findUserBadgesByBadgeId(badgeId, opts = {}) {
  const query = buildQuery({
    badge_id: badgeId,
    offset: opts.offset,
    username: opts.username,
  });
  return readMany(`/user_badges.json${query}`, normalizeUserBadgesPayload);
}

export function grantUserBadge(badgeId, username, reason) {
  return createOne(
    `/user_badges`,
    { username, badge_id: badgeId, reason },
    normalizeUserBadgeRecordPayload
  );
}

export function deleteUserBadge(id) {
  return deleteOne("user-badge", id, `/user_badges/${encodeURIComponent(id)}`);
}

// RPC-style: no `op` / `data` / normalizer.
export function toggleFavoriteUserBadge(id) {
  return {
    url: `/user_badges/${encodeURIComponent(id)}/toggle_favorite`,
    method: "PUT",
  };
}
