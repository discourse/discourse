import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel, later } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import SmoothStreamer from "../lib/smooth-streamer";

const DISCOVERY_TIMEOUT_MS = 20000;

export default class DiscobotDiscoveries extends Service {
  // We use this to retain state after search menu gets closed.
  // Similar to discourse/discourse#25504
  @service currentUser;

  @tracked discovery = "";
  @tracked lastQuery = "";
  @tracked discoveryTimedOut = false;
  @tracked modelUsed = "";
  @tracked loadingDiscoveries = false;

  @tracked
  smoothStreamer = new SmoothStreamer(
    () => this.discovery,
    (newValue) => (this.discovery = newValue)
  );

  discoveryTimeout = null;

  async onDiscoveryUpdate(update) {
    if (this.discoveryTimeout) {
      cancel(this.discoveryTimeout);
    }

    if (!this.discovery) {
      this.discovery = "";
    }

    this.modelUsed = update.model_used;
    this.loadingDiscoveries = false;
    this.smoothStreamer.updateResult(update, "ai_discover_reply");
  }

  resetDiscovery() {
    this.loadingDiscoveries = false;
    this.discovery = "";
    this.discoveryTimedOut = false;
    this.modelUsed = "";
    this.smoothStreamer.resetStreaming();
  }

  get showDiscoveryTitle() {
    return (
      this.discovery.length > 0 ||
      this.loadingDiscoveries ||
      this.discoveryTimedOut
    );
  }

  get isStreaming() {
    return this.smoothStreamer.isStreaming;
  }

  get streamedText() {
    return this.smoothStreamer?.renderedText;
  }

  @action
  async disableDiscoveries() {
    this.currentUser.user_option.ai_search_discoveries = false;
    await this.currentUser.save(["ai_search_discoveries"]);
    location.reload();
  }

  @action
  async triggerDiscovery(query) {
    if (this.lastQuery === query) {
      return;
    }

    this.resetDiscovery();

    if (query?.length === 0) {
      return;
    }

    this.loadingDiscoveries = true;

    this.discoveryTimeout = later(
      this,
      this.timeoutDiscovery,
      DISCOVERY_TIMEOUT_MS
    );

    try {
      this.lastQuery = query;

      await ajax("/discourse-ai/discoveries/reply", {
        data: { query },
      });
    } catch {
      this.timeoutDiscovery();
    }
  }

  timeoutDiscovery() {
    if (this.discovery?.length > 0) {
      return;
    }

    this.loadingDiscoveries = false;
    this.discovery = "";
    this.discoveryTimedOut = true;
  }
}
