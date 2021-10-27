import StickyAvatars from "discourse/lib/sticky-avatars";

export default {
  name: "sticky-avatars",
  after: "inject-objects",

  initialize(container) {
    StickyAvatars.init(container);
  },
};
