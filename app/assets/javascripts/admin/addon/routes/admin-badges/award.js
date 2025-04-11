import Route from "discourse/routes/discourse";

export default class AdminBadgesAwardRoute extends Route {
  model(params) {
    if (params.badge_id !== "new") {
      return parseInt(params.badge_id, 10);
    } else {
      return "new";
    }
  }
}
