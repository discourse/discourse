import Route from "@ember/routing/route";
export default Route.extend({
  beforeModel() {
    if (this.currentUser.admin) {
      this.transitionTo("adminCustomizeThemes");
    } else {
      this.transitionTo("adminWatchedWords");
    }
  },
});
