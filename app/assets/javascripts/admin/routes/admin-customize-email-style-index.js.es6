import Route from "@ember/routing/route";

export default Route.extend({
  beforeModel() {
    this.replaceWith("adminCustomizeEmailStyle.edit", "html");
  }
});
