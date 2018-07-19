export default Discourse.Route.extend({
  setupController(controller) {
    this._super(...arguments);

    if (!controller.get("start_date")) {
      controller.set(
        "start_date",
        moment()
          .subtract("30", "day")
          .format("YYYY-MM-DD")
      );
    }

    if (!controller.get("end_date")) {
      controller.set("end_date", moment().format("YYYY-MM-DD"));
    }
  }
});
