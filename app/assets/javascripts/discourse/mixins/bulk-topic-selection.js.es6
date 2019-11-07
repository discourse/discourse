import { alias } from "@ember/object/computed";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { on } from "discourse-common/utils/decorators";
import Mixin from "@ember/object/mixin";
import Topic from "discourse/models/topic";

export default Mixin.create({
  bulkSelectEnabled: false,
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

    dismissRead(operationType, categoryOptions) {
      let operation;
      if (operationType === "posts") {
        operation = { type: "dismiss_posts" };
      } else {
        operation = {
          type: "change_notification_level",
          notification_level_id: NotificationLevels.REGULAR
        };
      }

      let promise;
      if (this.selected.length > 0) {
        promise = Topic.bulkOperation(this.selected, operation);
      } else {
        promise = Topic.bulkOperationByFilter(
          "unread",
          operation,
          this.get("category.id"),
          categoryOptions
        );
      }

      promise.then(result => {
        if (result && result.topic_ids) {
          const tracker = this.topicTrackingState;
          result.topic_ids.forEach(t => tracker.removeTopic(t));
          tracker.incrementMessageCount();
        }

        this.send("closeModal");
        this.send("refresh");
      });
    }
  }
});
