import { service } from "discourse/lib/service";
import {
  homepageDestination,
  homepageRewriteParam,
  serverSideHomepage,
} from "discourse/lib/homepage-router-overrides";
import { disableImplicitInjections } from "discourse/lib/disable-implicit-injections";
import DiscourseURL from "discourse/lib/url";
import DiscourseRoute from "../discourse";
import CurrentUserService from "discourse/services/current-user";
import SiteSettingsService from "discourse/services/site-settings";

@disableImplicitInjections
export default class DiscoveryIndex extends DiscourseRoute {
  @service router;
  @service(() => CurrentUserService) currentUser;
  @service(() => SiteSettingsService) siteSettings;

  beforeModel(transition) {
    if (serverSideHomepage()) {
      DiscourseURL.redirectTo("/");
      return;
    }

    const url = transition.intent.url;
    const params = url?.split("?", 2)[1];
    let destination = homepageDestination();
    if (params) {
      destination += `&${params}`;
    }

    if (this.siteSettings.login_required && !this.currentUser) {
      destination = `/login-required?${homepageRewriteParam}=1`;
    }

    this.router.transitionTo(destination);
  }
}
