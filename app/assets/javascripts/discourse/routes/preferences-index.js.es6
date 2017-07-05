import RestrictedUserRoute from "discourse/routes/restricted-user";

export default RestrictedUserRoute.extend({
  redirect() {
    this.transitionTo('preferences.account');
  }
});
