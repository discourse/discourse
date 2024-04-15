import { service } from "@ember/service";
import { homepageDestination } from "discourse/lib/homepage-router-overrides";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import DiscourseRoute from "./discourse";

@disableImplicitInjections
export default class DiscoveryIndex extends DiscourseRoute {
  @service router;

  beforeModel(transition) {
    const url = transition.intent.url;
    const params = url?.split("?", 2)[1];
    let destination = homepageDestination();
    if (params) {
      destination += `&${params}`;
    }
    this.router.transitionTo(destination);
  }
}
