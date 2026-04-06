import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import GamificationLeaderboard from "discourse/plugins/discourse-gamification/discourse/models/gamification-leaderboard";

export default class DiscourseGamificationLeaderboardShow extends DiscourseRoute {
  async model(params) {
    const leaderboardsData = this.modelFor(
      "adminPlugins.show.discourse-gamification-leaderboards"
    );
    const id = parseInt(params.id, 10);

    const leaderboard = leaderboardsData.leaderboards.find(
      (item) => item.id === id
    );
    const resolved = leaderboard
      ? leaderboard
      : await ajax(
          `/admin/plugins/discourse-gamification/leaderboards/${id}`
        ).then((response) =>
          GamificationLeaderboard.create(response.leaderboard)
        );

    return {
      leaderboard: resolved,
      scoreDefaults: leaderboardsData.scoreDefaults,
    };
  }
}
