import { inject as service } from "@ember/service";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import computed from "ember-addons/ember-computed-decorators";
import Topic from "discourse/models/topic";

export default Controller.extend({
  router: service(),
  userTopicsList: inject("user-topics-list"),
  user: inject(),

  pmView: false,
  viewingSelf: Ember.computed.alias("user.viewingSelf"),
  isGroup: Ember.computed.equal("pmView", "groups"),
  currentPath: Ember.computed.alias("router._router.currentPath"),
  selected: Ember.computed.alias("userTopicsList.selected"),
  bulkSelectEnabled: Ember.computed.alias("userTopicsList.bulkSelectEnabled"),
  showToggleBulkSelect: true,
  pmTaggingEnabled: Ember.computed.alias("site.can_tag_pms"),
  tagId: null,

  showNewPM: Ember.computed.and(
    "user.viewingSelf",
    "currentUser.can_send_private_messages"
  ),

  @computed("selected.[]", "bulkSelectEnabled")
  hasSelection(selected, bulkSelectEnabled) {
    return bulkSelectEnabled && selected && selected.length > 0;
  },

  @computed("hasSelection", "pmView", "archive")
  canMoveToInbox(hasSelection, pmView, archive) {
    return hasSelection && (pmView === "archive" || archive);
  },

  @computed("hasSelection", "pmView", "archive")
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
