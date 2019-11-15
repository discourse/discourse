import Route from "@ember/routing/route";

export default Route.extend({
  actions: {
    show(apiKey) {
      this.transitionTo("adminApiKeys.show", apiKey.id);
    },

    new() {
      this.transitionTo("adminApiKeys.new");
    }
  }
});
