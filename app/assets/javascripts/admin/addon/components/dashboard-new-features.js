import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default Component.extend({
  newFeatures: null,
  classNames: ["section", "dashboard-new-features"],
  classNameBindings: ["hasUnseenFeatures:ordered-first"],
  releaseNotesLink: null,

  init() {
    this._super(...arguments);

    ajax("/admin/dashboard/new-features.json").then((json) => {
      if (!this.element || this.isDestroying || this.isDestroyed) {
        return;
      }

      this.setProperties({
        newFeatures: json.new_features,
        hasUnseenFeatures: json.has_unseen_features,
        releaseNotesLink: json.release_notes_link,
      });
    });
  },

  columnCountClass: computed("newFeatures", function () {
    return this.newFeatures.length > 2 ? "three-or-more-items" : "";
  }),

  @action
  dismissNewFeatures() {
    ajax("/admin/dashboard/mark-new-features-as-seen.json", {
      type: "PUT",
    }).then(() => this.set("hasUnseenFeatures", false));
  },
});
