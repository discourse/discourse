import Controller, { inject as controller } from "@ember/controller";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import { reads } from "@ember/object/computed";
import BulkTopicSelection from "discourse/mixins/bulk-topic-selection";
import { action } from "@ember/object";
import Topic from "discourse/models/topic";

import {
  NEW_FILTER,
  UNREAD_FILTER,
} from "discourse/routes/build-private-messages-route";

// Lists of topics on a user's page.
export default Controller.extend(BulkTopicSelection, {
  application: controller(),

  hideCategory: false,
  showPosters: false,
  channel: null,
  tagsForUser: null,
  pmTopicTrackingState: null,

  saveScrollPosition() {
    this.session.set("topicListScrollPosition", $(window).scrollTop());
  },

  @observes("model.canLoadMore")
  _showFooter() {
    this.set("application.showFooter", !this.get("model.canLoadMore"));
  },

  incomingCount: reads("pmTopicTrackingState.newIncoming.length"),

  @discourseComputed("filter", "model.topics.length")
  showResetNew(filter, hasTopics) {
    return filter === NEW_FILTER && hasTopics;
  },

  @discourseComputed("filter", "model.topics.length")
  showDismissRead(filter, hasTopics) {
    return filter === UNREAD_FILTER && hasTopics;
  },

  subscribe() {
    this.pmTopicTrackingState?.trackIncoming(
      this.inbox,
      this.filter,
      this.group
    );
  },

  unsubscribe() {
    this.pmTopicTrackingState?.resetTracking();
  },

  @action
  resetNew() {
    const topicIds = this.selected
      ? this.selected.map((topic) => topic.id)
      : null;

    const opts = {
      inbox: this.inbox,
      topicIds: topicIds,
    };

    if (this.group) {
      opts.groupName = this.group.name;
    }

    Topic.pmResetNew(opts).then(() => {
      this.send("refresh");
    });
  },

  @action
  loadMore() {
    this.model.loadMore();
  },

  @action
  showInserted() {
    this.model.loadBefore(this.pmTopicTrackingState.newIncoming);
    this.pmTopicTrackingState.resetTracking();
    return false;
  },
});
