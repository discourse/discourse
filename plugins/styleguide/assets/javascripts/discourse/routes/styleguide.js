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

  deactivate(transition) {
    // Only hand the sidebar back when the reader is actually leaving the styleguide. Releasing it
    // while moving between sections would flash the forum nav in between.
    if (!transition?.to.name.startsWith("styleguide")) {
      this.styleguideSidebar.hideSidebar();
    }
  }
}
