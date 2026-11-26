import RestrictedUserRoute from "discourse/routes/restricted-user";

export default class PreferencesSecurity extends RestrictedUserRoute {
  setupController(controller) {
    super.setupController(...arguments);
    controller.set("passwordProgress", null);
  }
}
