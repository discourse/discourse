import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class GamificationLeaderboardByName extends DiscourseRoute {
  @service router;

  model(params) {
    return ajax(`/leaderboard/${params.leaderboardId}`)
      .then((response) => {
        return response;
      })
      .catch(() => this.router.replaceWith("/404"));
  }
}
