import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import GamificationLeaderboard from "discourse/plugins/discourse-gamification/discourse/models/gamification-leaderboard";

export default class DiscourseGamificationLeaderboardShow extends DiscourseRoute {
  @service adminPluginNavManager;

  model(params) {
    const leaderboardsData = this.modelFor(
      "adminPlugins.show.discourse-gamification-leaderboards"
    );
    const id = parseInt(params.id, 10);

    const leaderboard = leaderboardsData.leaderboards.findBy("id", id);
    if (leaderboard) {
      return leaderboard;
    }

    return ajax(
      `/admin/plugins/discourse-gamification/leaderboards/${id}`
    ).then((response) => GamificationLeaderboard.create(response.leaderboard));
  }
}
