import Component from "@ember/component";
import I18n from "I18n";
import { or } from "@ember/object/computed";

export default Component.extend({
  tagName: "span",
  classNameBindings: [":topic-post-badges"],
  newDotText: null,

  init() {
    this._super(...arguments);

    this.set(
      "newDotText",
      this.currentUser && this.currentUser.trust_level > 0
        ? " "
        : I18n.t("filters.new.lower_title")
    );
  },

  displayUnreadPosts: or("newPosts", "unreadPosts"),
});
