import Route from "discourse/routes/discourse";

export default class AdminBadgesAwardRoute extends Route {
  model(params) {
    if (params.badge_id !== "new") {
      return this.modelFor("adminBadges").findBy(
        "id",
        parseInt(params.badge_id, 10)
      );
    }
  }

  setupController(controller) {
    super.setupController(...arguments);
    controller.resetState();
  }
}
