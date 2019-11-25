import RestrictedUserRoute from "discourse/routes/restricted-user";

export default RestrictedUserRoute.extend({
  showFooter: true,
  setupController(controller, model) {
    model.user_option.timezone =
      model.user_option.timezone || moment.tz.guess();
    controller.set("model", model);
  }
});
