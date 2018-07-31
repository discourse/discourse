import RestrictedUserRoute from "discourse/routes/restricted-user";

export default RestrictedUserRoute.extend({
  model() {
    return this.modelFor("user");
  }
});
