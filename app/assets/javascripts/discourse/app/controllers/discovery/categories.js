import Controller from "@ember/controller";
import { action } from "@ember/object";
import { reads } from "@ember/object/computed";
import { service } from "@ember/service";
import discourseComputed from "discourse/lib/decorators";

export default class CategoriesController extends Controller {
  @service router;
  @service composer;

  @reads("currentUser.staff") canEdit;

  @discourseComputed
  isCategoriesRoute() {
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
    this.composer.openNewTopic({
      preferDraft: true,
    });
  }

  @action
  refresh() {
    this.send("triggerRefresh");
  }
}
