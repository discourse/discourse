import Route from "@ember/routing/route";

export default class AdminCustomizeEmailStyleIndexRoute extends Route {
  beforeModel() {
    this.replaceWith("adminCustomizeEmailStyle.edit", "html");
  }
}
