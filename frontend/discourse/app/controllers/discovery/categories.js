import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { reads } from "@ember/object/computed";
import { service } from "@ember/service";

export default class CategoriesController extends Controller {
  @service router;
  @service composer;

  @reads("currentUser.staff") canEdit;

  @computed
  get isCategoriesRoute() {
    return this.router.currentRouteName === "discovery.categories";
  }

  @action
  showInserted(event) {
    event?.preventDefault();
    const tracker = this.topicTrackingState;
    // Move inserted into topics
    this.model.loadBefore(tracker.get("newIncoming"), true);
    tracker.resetTracking();
  }

  @action
  createTopic() {
    this.composer.openNewTopic();
  }

  @action
  refresh() {
    this.send("triggerRefresh");
  }
}
