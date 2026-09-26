import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { getOwner } from "@ember/owner";
import { lazyLookup, service } from "discourse/lib/service";

export default class CategoriesController extends Controller {
  @service router;

  @tracked _canEditOverride;

  @computed("currentUser.staff")
  get canEdit() {
    if (this._canEditOverride !== undefined) {
      return this._canEditOverride;
    }
    return this.currentUser?.staff;
  }

  set canEdit(value) {
    this._canEditOverride = value;
  }

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
    lazyLookup(
      getOwner(this),
      () => import("discourse/services/composer")
    ).then((composer) => composer.openNewTopic());
  }

  @action
  refresh() {
    this.send("triggerRefresh");
  }
}
