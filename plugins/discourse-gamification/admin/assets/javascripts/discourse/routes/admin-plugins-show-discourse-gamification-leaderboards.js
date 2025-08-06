import EmberObject from "@ember/object";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import GamificationLeaderboard from "discourse/plugins/discourse-gamification/discourse/models/gamification-leaderboard";

export default class DiscourseGamificationLeaderboards extends DiscourseRoute {
  @service adminPluginNavManager;

  model() {
    if (!this.currentUser?.admin) {
      return { model: null };
    }
    const gamificationPlugin = this.adminPluginNavManager.currentPlugin;

    return EmberObject.create({
      leaderboards: gamificationPlugin.extras.gamification_leaderboards.map(
        (leaderboard) => GamificationLeaderboard.create(leaderboard)
      ),
      groups: gamificationPlugin.extras.gamification_groups,
      recalculate_scores_remaining:
        gamificationPlugin.extras.gamification_recalculate_scores_remaining,
    });
  }
}
