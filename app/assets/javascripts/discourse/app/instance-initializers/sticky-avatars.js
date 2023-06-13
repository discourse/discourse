import StickyAvatars from "discourse/lib/sticky-avatars";

export default {
  after: "inject-objects",

  initialize(owner) {
    this._stickyAvatars = StickyAvatars.init(owner);
  },

  teardown() {
    this._stickyAvatars?.destroy();
  },
};
