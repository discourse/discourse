import Component from "@ember/component";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default Component.extend({
  newFeatures: null,
  releaseNotesLink: null,

  init() {
    this._super(...arguments);

    ajax("/admin/dashboard/new-features.json").then((json) => {
      this.setProperties({
        newFeatures: json.new_features,
        releaseNotesLink: json.release_notes_link,
      });
    });
  },

  @action
  dismissNewFeatures() {
    ajax("/admin/dashboard/mark-new-features-as-seen.json", {
      type: "PUT",
    }).then(() => this.set("newFeatures", null));
  },
});
