import Route from "@ember/routing/route";
export default Route.extend({
  model() {
    return this.store.find("email-style");
  },

  redirect() {
    this.transitionTo("adminCustomizeEmailStyle.edit", "html");
  }
});
