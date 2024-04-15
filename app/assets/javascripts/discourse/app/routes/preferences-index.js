import { service } from "@ember/service";
import RestrictedUserRoute from "discourse/routes/restricted-user";

export default RestrictedUserRoute.extend({
  router: service(),

  redirect() {
    this.router.transitionTo("preferences.account");
  },
});
