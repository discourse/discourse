import RestrictedUserRoute from "discourse/routes/restricted-user";

export default class PreferencesCalendarSubscriptions extends RestrictedUserRoute {
  setupController(controller, user) {
    controller.set("model", user);
  }
}
