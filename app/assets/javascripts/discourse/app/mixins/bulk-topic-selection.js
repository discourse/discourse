import Mixin from "@ember/object/mixin";
import { NotificationLevels } from "discourse/lib/notification-levels";
import Topic from "discourse/models/topic";
import { alias } from "@ember/object/computed";
import { on } from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";

export default Mixin.create({
  router: service(),

  bulkSelectEnabled: false,
  autoAddTopicsToBulkSelect: false,
  selected: null,

  canBulkSelect: alias("currentUser.staff"),

  @on("init")
  resetSelected() {
    this.set("selected", []);
  },

  actions: {
    toggleBulkSelect() {
      this.toggleProperty("bulkSelectEnabled");
      this.selected.clear();
    },

    dismissRead(operationType, options) {
      const operation =
        operationType === "posts"
          ? { type: "dismiss_posts" }
          : {
              type: "change_notification_level",
              notification_level_id: NotificationLevels.REGULAR,
            };

      const tracked =
        (this.router.currentRoute.queryParams["f"] ||
          this.router.currentRoute.queryParams["filter"]) === "tracked";

      const promise = this.selected.length
        ? Topic.bulkOperation(this.selected, operation, tracked)
        : Topic.bulkOperationByFilter("unread", operation, options, tracked);

      promise.then((result) => {
        if (result && result.topic_ids) {
          const tracker = this.topicTrackingState;
          result.topic_ids.forEach((t) => tracker.removeTopic(t));
          tracker.incrementMessageCount();
        }

        this.send("closeModal");
        this.send(
          "refresh",
          tracked ? { skipResettingParams: ["filter", "f"] } : {}
        );
      });
    },

    updateAutoAddTopicsToBulkSelect(newVal) {
      this.set("autoAddTopicsToBulkSelect", newVal);
    },

    addTopicsToBulkSelect(topics) {
      this.selected.pushObjects(topics);
    },
  },
});
