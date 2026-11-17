import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class AdminWhatsNewController extends Controller {
  /** @type {string | null} */
  @tracked scrollTo = null;
  queryParams = ["scrollTo"];

  @action
  checkForUpdates() {
    this.checkFeaturesCallback?.({ forceRefresh: true });
  }

  @action
  bindCheckFeatures(checkFeaturesCallback) {
    this.checkFeaturesCallback = checkFeaturesCallback;
  }
}
