import { service } from "@ember/service";
import {
  homepageDestination,
  homepageRewriteParam,
  serverSideHomepage,
} from "discourse/lib/homepage-router-overrides";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import DiscourseURL from "discourse/lib/url";
import DiscourseRoute from "../discourse";

@disableImplicitInjections
export default class DiscoveryIndex extends DiscourseRoute {
  @service router;
  @service currentUser;
  @service siteSettings;

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
