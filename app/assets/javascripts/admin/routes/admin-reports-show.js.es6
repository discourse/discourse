export default Discourse.Route.extend({
  setupController(controller) {
    this._super(...arguments);

    if (!controller.get("start_date")) {
      controller.set(
        "start_date",
        moment
          .utc()
          .subtract(1, "day")
          .subtract(1, "month")
          .startOf("day")
          .format("YYYY-MM-DD")
      );
    }

    if (!controller.get("end_date")) {
      controller.set(
        "end_date",
        moment()
          .utc()
          .endOf("day")
          .format("YYYY-MM-DD")
      );
    }
  }
});
