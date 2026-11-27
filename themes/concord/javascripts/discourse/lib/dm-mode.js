import { tracked } from "@glimmer/tracking";
import { CHANNELS_PANEL, DMS_PANEL } from "./constants.js";

/**
 * Whether the sidebar shows direct messages (the Home view) rather than the
 * server's channels. A module of its own because the sidebar state patch
 * reads it from a pre-initializer, before anything else is set up.
 */
class DmMode {
  @tracked active = false;

  get panel() {
    return this.active ? DMS_PANEL : CHANNELS_PANEL;
  }
}

export default new DmMode();
