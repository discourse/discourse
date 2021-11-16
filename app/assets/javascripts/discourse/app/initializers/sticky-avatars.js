import StickyAvatars from "discourse/lib/sticky-avatars";

export default {
  name: "sticky-avatars",
  after: "inject-objects",

  initialize(container) {
    this._stickyAvatar = StickyAvatars.init(container);
  },

  teardown() {
    this._stickyAvatar?.destroy();
  },
};
