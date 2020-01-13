import Route from "discourse/routes/discourse";

export default Route.extend({
  model(params) {
    if (params.badge_id !== "new") {
      return this.modelFor("adminBadges").findBy(
        "id",
        parseInt(params.badge_id, 10)
      );
    }
  }
});
