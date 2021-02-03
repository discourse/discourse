import Controller, { inject as controller } from "@ember/controller";
import { alias, and, equal } from "@ember/object/computed";
import I18n from "I18n";
import Topic from "discourse/models/topic";
import bootbox from "bootbox";
import discourseComputed from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";

export default Controller.extend({
  userTopicsList: controller("user-topics-list"),
  user: controller(),
  router: service(),

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
    let params = { type: operation };
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
      this.group.setNotification(notificationLevel, this.get("user.model.id"));
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
    },
  },
});
