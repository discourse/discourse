import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import Service from "@ember/service";

export default class Exception extends Service {
  @tracked thrown = null;
  @tracked lastTransition = null;

  /**
   * Renders the error page in place of the current route's content, leaving the
   * URL untouched so that a reload retries the page the user asked for.
   *
   * @param {unknown} thrown - The error or failed XHR to display
   * @param {Transition} [lastTransition] - Transition to retry via the "try again" button
   */
  show(thrown, lastTransition = null) {
    this.thrown = thrown;
    this.lastTransition = lastTransition;
    // eslint-disable-next-line ember/no-private-routing-service -- `intermediateTransitionTo` is not exposed on the router service
    getOwner(this).lookup("router:main").intermediateTransitionTo("exception");
  }

  clear() {
    this.thrown = null;
    this.lastTransition = null;
  }
}
