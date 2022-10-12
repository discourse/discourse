import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { defaultHomepage } from "discourse/lib/utilities";

export default class RouteControl extends Component {
  @service router;
  @service siteSettings;
  @service currentUser;

  get canDisplay() {
    const currentRouteName = this.router.currentRouteName;
    const showOn = this.args.showOn;
    const minTrustLevel = this.args.options?.minTrustLevel;
    const requireUser = this.args.options?.requireUser
      ? this.args.options?.requireUser
      : false;

    if (requireUser && !this.currentUser) {
      return;
    }

    if (
      (minTrustLevel && this.currentUser?.trust_level < minTrustLevel) ||
      (minTrustLevel && !this.currentUser)
    ) {
      return;
    }

    if (showOn === "homepage") {
      return this.#handleHomepageRoute(currentRouteName);
    } else if (showOn === currentRouteName) {
      return true;
    } else {
      return false;
    }
  }

  #handleHomepageRoute(currentRouteName) {
    const topMenu = this.siteSettings.top_menu;

    if (currentRouteName === `discovery.${defaultHomepage()}`) {
      return true;
    } else if (
      topMenu.split("|").any((m) => `discovery.${m}` === currentRouteName)
    ) {
      return true;
    } else {
      return false;
    }
  }
}
