import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  setupController(controller) {
    controller.setProperties({
      loading: true,
      filter: { status: this.status }
    });
  }
});
