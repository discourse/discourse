import Route from "@ember/routing/route";

export default class AdminConfigThemeShowRoute extends Route {
  model(params) {
    return this.store.find("theme", params.id);
  }
}
