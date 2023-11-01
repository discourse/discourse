import Component from "@ember/component";
import { classNameBindings, classNames } from "@ember-decorators/component";
import { ajax } from "discourse/lib/ajax";

@classNames("section", "dashboard-new-features")
@classNameBindings("hasUnseenFeatures:ordered-first")
export default class DashboardNewFeatures extends Component {
  newFeatures = null;

  constructor() {
    super(...arguments);

    ajax("/admin/dashboard/new-features.json").then((json) => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.setProperties({
        newFeatures: json.new_features,
        hasUnseenFeatures: json.has_unseen_features,
      });
    });
  }
}
