import discourseComputed from "discourse-common/utils/decorators";
import { alias, equal, and } from "@ember/object/computed";
import { inject as service } from "@ember/service";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import Topic from "discourse/models/topic";

export default Controller.extend({
  router: service(),
  userTopicsList: inject("user-topics-list"),
  user: inject(),

  pmView: false,
  viewingSelf: alias("user.viewingSelf"),
  isGroup: equal("pmView", "groups"),
  currentPath: alias("router._router.currentPath"),
  selected: alias("userTopicsList.selected"),
  bulkSelectEnabled: alias("userTopicsList.bulkSelectEnabled"),
  showToggleBulkSelect: true,
  pmTaggingEnabled: alias("site.can_tag_pms"),
  tagId: null,

  showNewPM: and("user.viewingSelf", "currentUser.can_send_private_messages"),

  @discourseComputed("selected.[]", "bulkSelectEnabled")
  hasSelection(selected, bulkSelectEnabled) {
    return bulkSelectEnabled && selected && selected.length > 0;
  },

  @discourseComputed("hasSelection", "pmView", "archive")
  canMoveToInbox(hasSelection, pmView, archive) {
    return hasSelection && (pmView === "archive" || archive);
  },

  @discourseComputed("hasSelection", "pmView", "archive")
  canArchive(hasSelection, pmView, archive) {
    return hasSelection && pmView !== "archive" && !archive;
  },

  bulkOperation(operation) {
    const selected = this.selected;
    var params = { type: operation };
    if (this.isGroup) {
      params.group = this.groupFilter;
    }

    Topic.bulkOperation(selected, params).then(
      () => {
        const model = this.get("userTopicsList.model");
        const topics = model.get("topics");
        topics.removeObjects(selected);
        selected.clear();
        model.loadMore();
      },
      () => {
        bootbox.alert(I18n.t("user.messages.failed_to_move"));
      }
    );
  },

  actions: {
    changeGroupNotificationLevel(notificationLevel) {
      this.group.setNotification(notificationLevel, this.get("user.id"));
    },
    archive() {
      this.bulkOperation("archive_messages");
    },
    toInbox() {
      this.bulkOperation("move_messages_to_inbox");
    },
    toggleBulkSelect() {
      this.toggleProperty("bulkSelectEnabled");
    },
    selectAll() {
      $("input.bulk-select:not(checked)").click();
    }
  }
});
