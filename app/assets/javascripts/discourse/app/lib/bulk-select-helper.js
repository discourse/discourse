import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner, setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { NotificationLevels } from "discourse/lib/notification-levels";
import Topic from "discourse/models/topic";

export default class BulkSelectHelper {
  @service router;
  @service modal;
  @service pmTopicTrackingState;
  @service topicTrackingState;

  @tracked bulkSelectEnabled = false;
  @tracked autoAddTopicsToBulkSelect = false;
  @tracked autoAddBookmarksToBulkSelect = false;

  selected = new TrackedArray();

  constructor(context) {
    setOwner(this, getOwner(context));
  }

  clear() {
    this.selected.length = 0;
  }

  addTopics(topics) {
    this.selected.concat(topics);
  }

  get selectedCategoryIds() {
    return this.selected.mapBy("category_id").uniq();
  }

  @action
  toggleBulkSelect(event) {
    event.preventDefault();
    this.bulkSelectEnabled = !this.bulkSelectEnabled;
    this.clear();
  }

  dismissRead(operationType, options) {
    const operation =
      operationType === "posts"
        ? { type: "dismiss_posts" }
        : {
            type: "change_notification_level",
            notification_level_id: NotificationLevels.REGULAR,
          };

    const isTracked =
      (this.router.currentRoute.queryParams["f"] ||
        this.router.currentRoute.queryParams["filter"]) === "tracked";

    const promise = this.selected.length
      ? Topic.bulkOperation(this.selected, operation, {}, isTracked)
      : Topic.bulkOperationByFilter("unread", operation, options, isTracked);

    promise.then((result) => {
      if (result?.topic_ids) {
        if (options?.private_message_inbox) {
          this.pmTopicTrackingState.removeTopics(result.topic_ids);
        } else {
          this.topicTrackingState.removeTopics(result.topic_ids);
        }
      }

      this.modal.close();
      this.router.refresh();
    });
  }
}
