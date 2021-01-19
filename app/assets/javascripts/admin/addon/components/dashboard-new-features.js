import AdminDashboard from "admin/models/admin-dashboard";
import Component from "@ember/component";
import { action } from "@ember/object";

export default Component.extend({
  newFeatures: null,
  releaseNotesLink: null,

  init() {
    this._super(...arguments);

    AdminDashboard.fetchNewFeatures().then((model) => {
      this.setProperties({
        newFeatures: model.new_features,
        releaseNotesLink: model.release_notes_link,
      });
    });
  },

  @action
  dismissNewFeatures() {
    AdminDashboard.dismissNewFeatures().then(() =>
      this.set("newFeatures", null)
    );
  },
});
