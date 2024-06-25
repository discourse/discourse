import RestrictedUserRoute from "discourse/routes/restricted-user";

export default class PreferencesProfile extends RestrictedUserRoute {
  setupController(controller, model) {
    controller.set("model", model);
  }
}
