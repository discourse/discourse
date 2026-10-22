import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

// Keeps links to the old `leaderboards/:id` edit URL working.
export default class DiscourseGamificationLeaderboardShow extends DiscourseRoute {
  @service router;

  beforeModel(transition) {
    this.router.replaceWith(
      "adminPlugins.show.discourse-gamification-leaderboards.edit",
      transition.to.params.id
    );
  }
}
