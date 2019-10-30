import { NotificationLevels } from "discourse/lib/notification-levels";
import { on } from "ember-addons/ember-computed-decorators";
import Mixin from '@ember/object/mixin';

export default Mixin.create({
  bulkSelectEnabled: false,
  selected: null,

  canBulkSelect: Ember.computed.alias("currentUser.staff"),

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
        promise = Discourse.Topic.bulkOperation(this.selected, operation);
      } else {
        promise = Discourse.Topic.bulkOperationByFilter(
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
