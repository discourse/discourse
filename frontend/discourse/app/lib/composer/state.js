import { tracked } from "@glimmer/tracking";
import { get } from "@ember/object";

// Boot-time code reads the composer's state from here, so the composer
// service itself only loads when something opens it. The service stores its
// model classically, so reads go through `get` to stay tracked.
class ComposerState {
  @tracked service = null;

  get visible() {
    return this.service ? get(this.service, "visible") : false;
  }

  get isOpen() {
    return this.service ? get(this.service, "isOpen") : false;
  }

  get model() {
    return this.service ? get(this.service, "model") : null;
  }
}

export const composerState = new ComposerState();
