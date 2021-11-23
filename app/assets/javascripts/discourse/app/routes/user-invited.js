import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  setupController(controller) {
    const can_see_invite_details =
      this.currentUser.staff ||
      this.controllerFor("user").id === this.currentUser?.id;

    controller.setProperties({
      can_see_invite_details,
    });
  },
});
