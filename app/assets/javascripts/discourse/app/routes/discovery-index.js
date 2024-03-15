import { service } from "@ember/service";
import { homepageDestination } from "discourse/lib/homepage-router-overrides";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import DiscourseRoute from "./discourse";

@disableImplicitInjections
export default class DiscoveryIndex extends DiscourseRoute {
  @service router;

  beforeModel(transition) {
    const { intent } = transition || {};
    const { url, queryParams } = intent || {};
    const urlParams = new URLSearchParams(url?.split("?", 2)[1]);

    if (queryParams) {
      for (const [key, value] of Object.entries(queryParams)) {
        if (value !== null && value !== undefined) {
          urlParams.set(key, value);
        }
      }
    }

    let destination = homepageDestination();

    if (urlParams.size > 0) {
      destination += `&${urlParams}`;
    }

    this.router.transitionTo(destination);
  }
}
