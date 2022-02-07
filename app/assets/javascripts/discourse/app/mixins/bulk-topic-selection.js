import Mixin from "@ember/object/mixin";
import { or } from "@ember/object/computed";
import { on } from "discourse-common/utils/decorators";
import { NotificationLevels } from "discourse/lib/notification-levels";
import Topic from "discourse/models/topic";
import { inject as service } from "@ember/service";

export default Mixin.create({
  router: service(),

  bulkSelectEnabled: false,
  autoAddTopicsToBulkSelect: false,
  selected: null,
  lastChecked: null,

  canBulkSelect: or("currentUser.staff", "showDismissRead", "showResetNew"),

  @on("init")
  resetSelected() {
    this.set("selected", []);
  },

  _isFilterPage(filter, filterType) {
    if (!filter) {
      return false;
    }
    return new RegExp(filterType + "$", "gi").test(filter);
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
          if (options.private_message_inbox) {
            this.pmTopicTrackingState.removeTopics(result.topic_ids);
          } else {
            this.topicTrackingState.removeTopics(result.topic_ids);
          }
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
