import RestrictedUserRoute from "discourse/routes/restricted-user";
import { inject as service } from "@ember/service";

export default RestrictedUserRoute.extend({
  router: service(),
  showFooter: true,

  redirect() {
    this.router.transitionTo("preferences.account");
  },
});
