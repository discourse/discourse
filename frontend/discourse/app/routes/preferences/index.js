import { service } from "@ember/service";
import RestrictedUserRoute from "discourse/routes/restricted-user";

export default class PreferencesIndex extends RestrictedUserRoute {
  @service router;

  redirect() {
    this.router.transitionTo("preferences.account");
  }
}
