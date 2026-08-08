import Route from "@ember/routing/route";
import { service } from "@ember/service";
import loadFaker from "discourse/lib/load-faker";
import { allCategories } from "discourse/plugins/styleguide/discourse/lib/styleguide";

export default class Styleguide extends Route {
  @service styleguideSidebar;

  async model() {
    await loadFaker(); // So that it can be used synchronously in styleguide components
    return allCategories();
  }

  activate() {
    this.styleguideSidebar.showSidebar();
  }

  deactivate() {
    this.styleguideSidebar.hideSidebar();
  }
}
