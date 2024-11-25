import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class AdminWhatsNewController extends Controller {
  @action
  checkForUpdates() {
    if (this.checkFeaturesCallback) {
      this.checkFeaturesCallback({ forceRefresh: true });
    }
  }

  @action
  bindCheckFeatures(checkFeaturesCallback) {
    this.checkFeaturesCallback = checkFeaturesCallback;
  }
}
