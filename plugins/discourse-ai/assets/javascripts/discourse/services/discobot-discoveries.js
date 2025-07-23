import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";

export default class DiscobotDiscoveries extends Service {
  // We use this to retain state after search menu gets closed.
  // Similar to discourse/discourse#25504
  @service currentUser;

  @tracked discovery = "";
  @tracked lastQuery = "";
  @tracked discoveryTimedOut = false;
  @tracked modelUsed = "";
  @tracked loadingDiscoveries = false;

  resetDiscovery() {
    this.loadingDiscoveries = false;
    this.discovery = "";
    this.discoveryTimedOut = false;
    this.modelUsed = "";
  }

  get showDiscoveryTitle() {
    return (
      this.discovery.length > 0 ||
      this.loadingDiscoveries ||
      this.discoveryTimedOut
    );
  }

  @action
  async disableDiscoveries() {
    this.currentUser.user_option.ai_search_discoveries = false;
    await this.currentUser.save(["ai_search_discoveries"]);
    location.reload();
  }
}
