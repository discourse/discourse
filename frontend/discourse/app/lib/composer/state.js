import { tracked } from "@glimmer/tracking";

// Boot-time code reads the composer's state from here, so the composer
// service itself only loads when something opens it.
class ComposerState {
  @tracked service = null;

  get visible() {
    return this.service?.visible ?? false;
  }

  get isOpen() {
    return this.service?.isOpen ?? false;
  }

  get model() {
    return this.service?.model ?? null;
  }
}

export const composerState = new ComposerState();
