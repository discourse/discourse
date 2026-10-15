import { ajax } from "discourse/lib/ajax";

const DEFAULT_USER_LIMIT = 10;

/**
 * Fetches a gamification leaderboard and annotates it for rendering: marks the
 * current user's row and the top-ranked row. When `id` is blank the site's
 * default leaderboard is used. Shared by the self-fetching
 * `MinimalGamificationLeaderboard` component and the block's `data.resolve`.
 *
 * `ignoreUnsent: false` so a failed or offline request rejects rather than
 * hanging, letting the caller surface an error.
 *
 * @param {object} [params]
 * @param {number} [params.id] - A specific leaderboard ID; omit for the default.
 * @param {number} [params.count] - Number of users to request.
 * @param {string} [params.period] - Optional scoring period (e.g. "weekly").
 * @returns {Promise<object>} The leaderboard model with annotated users.
 */
export async function fetchLeaderboard({ id, count, period } = {}) {
  const endpoint = id ? `/leaderboard/${id}` : "/leaderboard";

  const data = { user_limit: count || DEFAULT_USER_LIMIT };
  if (period) {
    data.period = period;
  }

  const model = await ajax(endpoint, { data, ignoreUnsent: false });

  for (const user of model.users) {
    if (user.id === model.personal?.user?.id) {
      user.isCurrentUser = "true";
    }
  }

  if (model.users[0]) {
    model.users[0].topRanked = true;
  }

  return model;
}
